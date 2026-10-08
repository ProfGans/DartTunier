import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:dart_tournament_manager/shared/persistence/storage_access.dart';
import 'package:dart_tournament_manager/features/scorer/domain/scorer_hit.dart';
import 'package:dart_tournament_manager/shared/utils/background_worker.dart';
import 'package:dart_tournament_manager/shared/widgets/paged_entries.dart';
import 'package:dart_tournament_manager/features/tournaments/data/app_database.dart';
import 'package:dart_tournament_manager/features/statistics/data/scorer_heatmap_repository.dart';
import 'package:dart_tournament_manager/features/statistics/domain/analytics/statistics_report.dart';
import 'package:dart_tournament_manager/features/statistics/domain/analytics/statistics_metric.dart';
import 'package:dart_tournament_manager/features/autoscoring/application/frame_analysis_worker.dart';
import 'package:dart_tournament_manager/features/autoscoring/domain/frame_detector.dart';
import 'package:dart_tournament_manager/features/autoscoring/domain/board_geometry.dart';

Future<int> _delayed(int input) async {
  await Future<void>.delayed(const Duration(milliseconds: 50));
  if (input < 0) throw StateError('expected');
  return input * 2;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('worker can be cancelled during startup', () async {
    final worker = BackgroundWorker<int, int>(_delayed);
    final result = worker.run(1);
    final assertion = expectLater(result, throwsStateError);
    worker.close();
    await assertion;
  });

  for (final size in [
    const Size(360, 800),
    const Size(800, 600),
    const Size(1440, 900),
  ]) {
    testWidgets('pagination wraps at $size with large text', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: Scaffold(
            body: SingleChildScrollView(
              child: PagedEntries<int>(
                entries: List.generate(1000, (i) => i),
                builder: (i) => Text('Eintrag $i'),
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Nächste Seite'));
      await tester.pumpAndSettle();
      expect(find.text('Eintrag 40'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  test(
    'version 3 migration preserves a usable pre-migration database',
    () async {
      final dir = await Directory.systemTemp.createTemp('heatmap_v3_');
      addTearDown(() => dir.delete(recursive: true));
      final database = LocalAppDatabase(baseDirectory: dir);
      await database.withDatabase((db) async {
        db.execute('DROP TABLE heatmap_sessions');
        db.execute('DROP TABLE heatmap_migration');
        db.execute('PRAGMA user_version = 3');
      });
      SharedPreferences.setMockInitialValues({});
      await ScorerHeatmapRepository(database: database).load();
      final backup = dir.listSync().whereType<File>().singleWhere(
        (f) => f.path.endsWith('.bak'),
      );
      final original = sqlite3.open(backup.path, mode: OpenMode.readOnly);
      try {
        expect(original.select('PRAGMA user_version').single.values.single, 3);
        expect(
          original.select(
            "SELECT name FROM sqlite_master WHERE name='heatmap_sessions'",
          ),
          isEmpty,
        );
      } finally {
        original.close();
      }
    },
  );

  test(
    'waiting saves coalesce per session and keep other sessions intact',
    () async {
      final dir = await Directory.systemTemp.createTemp('heatmap_coalesce_');
      addTearDown(() => dir.delete(recursive: true));
      final database = LocalAppDatabase(baseDirectory: dir);
      SharedPreferences.setMockInitialValues({});
      final repo = ScorerHeatmapRepository(database: database);
      await repo.load();
      await database.withDatabase((db) async {
        db.execute('CREATE TABLE writes (id TEXT)');
        db.execute(
          'CREATE TRIGGER count_write AFTER INSERT ON heatmap_sessions BEGIN INSERT INTO writes VALUES (NEW.id); END',
        );
      });
      final release = Completer<void>();
      final entered = Completer<void>();
      final blocker = StorageAccess.run(() async {
        entered.complete();
        await release.future;
      });
      await entered.future;
      ScorerHeatmapSession session(String id, int score) =>
          ScorerHeatmapSession(
            id: id,
            date: DateTime(2026),
            names: ['P'],
            hits: [
              ScorerHit(
                location: const DartLocation(0, 0),
                player: 0,
                leg: 0,
                thrower: 'P',
                label: '$score',
                points: score,
                checkoutAttempt: false,
              ),
            ],
          );
      final saves = [
        for (var i = 0; i < 20; i++) repo.save(session('same', i)),
        repo.save(session('other', 60)),
      ];
      await Future<void>.delayed(const Duration(milliseconds: 30));
      release.complete();
      await blocker;
      await Future.wait(saves);
      final stored = await repo.load();
      expect(stored.singleWhere((s) => s.id == 'same').hits.single.points, 19);
      expect(stored.singleWhere((s) => s.id == 'other').hits.single.points, 60);
      await database.withDatabase((db) async {
        expect(db.select('SELECT * FROM writes').length, 2);
      });
    },
  );
  test(
    'worker reusable, rejects backlog, propagates failure and cancellation',
    () async {
      final worker = BackgroundWorker<int, int>(_delayed);
      expect(await worker.run(2), 4);
      final first = worker.run(3);
      await expectLater(worker.run(4), throwsStateError);
      expect(await first, 6);
      await expectLater(worker.run(-1), throwsStateError);
      worker.close();
      final cancellable = BackgroundWorker<int, int>(_delayed);
      expect(await cancellable.run(1), 2);
      final pending = cancellable.run(4);
      final check = expectLater(pending, throwsStateError);
      await Future<void>.delayed(const Duration(milliseconds: 5));
      cancellable.close();
      await check;
    },
  );

  test('background camera analysis matches synchronous detector', () async {
    final reference = GrayFrame(100, 100, Uint8List(10000));
    final pixels = Uint8List(10000);
    for (var y = 20; y < 75; y++) {
      pixels[y * 100 + 50] = 255;
    }
    final frame = GrayFrame(100, 100, pixels);
    final calibration = BoardCalibration(const [
      BoardPoint(50, 0),
      BoardPoint(100, 50),
      BoardPoint(50, 100),
      BoardPoint(0, 50),
    ]);
    final inputs = [
      for (var i = 0; i < 3; i++)
        (
          previous: reference,
          reference: reference,
          frame: frame,
          calibration: calibration,
        ),
    ];
    final worker =
        BackgroundWorker<List<CameraAnalysisInput>, List<CameraAnalysis>>(
          analyzeCameraFrames,
        );
    addTearDown(worker.close);
    final actual = await worker.run(inputs),
        expected = analyzeCameraFrames(inputs);
    for (var i = 0; i < 3; i++) {
      expect(actual[i].changeFraction, expected[i].changeFraction);
      expect(actual[i].axis?.a, expected[i].axis?.a);
      expect(actual[i].axis?.b, expected[i].axis?.b);
      expect(actual[i].axis?.c, expected[i].axis?.c);
      expect(
        actual[i].changedPixels.map((p) => (p.x, p.y)),
        expected[i].changedPixels.map((p) => (p.x, p.y)),
      );
    }
  });

  test('immutable cached reports preserve all prefix aggregations', () {
    final source = {'points': 60.0, 'darts': 3.0, 'matches': 1.0};
    final rows = List.generate(
      80,
      (i) => StatisticsObservation(
        id: '$i',
        playerId: '${i % 3}',
        name: 'P',
        label: '$i',
        date: DateTime(2026).add(Duration(days: i)),
        values: source,
      ),
    );
    source['points'] = 0;
    final report = StatisticsReport(rows);
    expect(report.observations.first.values['points'], 60);
    expect(() => report.observations.clear(), throwsUnsupportedError);
    expect(report.byPlayer['0']!.observations.length, 27);
    for (final metric in statisticsMetrics) {
      final series = report.series(metric);
      expect(identical(series, report.series(metric)), true);
      final cumulative = report.cumulative(metric);
      for (var i = 0; i < series.length; i++) {
        expect(
          cumulative[i],
          report.value(metric, series.take(i + 1).map((p) => p.$1)),
        );
      }
    }
  });

  test(
    'heatmap migration is transactional, keeps original and never reimports deleted sessions',
    () async {
      final dir = await Directory.systemTemp.createTemp('heatmap_migration_');
      addTearDown(() => dir.delete(recursive: true));
      final database = LocalAppDatabase(baseDirectory: dir);
      final session = ScorerHeatmapSession(
        id: 'legacy',
        date: DateTime(2026),
        names: ['A'],
        hits: [],
      );
      final raw = jsonEncode({
        'version': 1,
        'sessions': [session.toJson()],
      });
      SharedPreferences.setMockInitialValues({
        'scorer_heatmap_archive_v1': raw,
      });
      final repo = ScorerHeatmapRepository(database: database);
      expect((await repo.load()).single.id, 'legacy');
      await repo.save(session);
      expect(await repo.load(), isEmpty);
      await database.withDatabase((db) async {
        expect(
          db
              .select('SELECT legacy_json FROM heatmap_migration')
              .single['legacy_json'],
          raw,
        );
        expect(db.select('PRAGMA user_version').single.values.single, 4);
      });
      expect(await ScorerHeatmapRepository(database: database).load(), isEmpty);
      expect(
        (await SharedPreferences.getInstance()).getString(
          'scorer_heatmap_archive_v1',
        ),
        raw,
      );
    },
  );

  test(
    'invalid legacy archive stays retryable without partial import',
    () async {
      final dir = await Directory.systemTemp.createTemp('heatmap_invalid_');
      addTearDown(() => dir.delete(recursive: true));
      final database = LocalAppDatabase(baseDirectory: dir);
      SharedPreferences.setMockInitialValues({
        'scorer_heatmap_archive_v1': '{"version":99,"sessions":[]}',
      });
      await expectLater(
        ScorerHeatmapRepository(database: database).load(),
        throwsFormatException,
      );
      await database.withDatabase((db) async {
        expect(db.select('SELECT * FROM heatmap_migration'), isEmpty);
        expect(db.select('SELECT * FROM heatmap_sessions'), isEmpty);
      });
      SharedPreferences.setMockInitialValues({});
      expect(await ScorerHeatmapRepository(database: database).load(), isEmpty);
    },
  );

  testWidgets(
    'long history builds only one page and exposes remaining entries',
    (tester) async {
      final built = <int>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: PagedEntries<int>(
                entries: List.generate(1000, (i) => i),
                builder: (i) {
                  built.add(i);
                  return Text('Entry $i');
                },
              ),
            ),
          ),
        ),
      );
      expect(built.length, 40);
      expect(find.text('Entry 40'), findsNothing);
      await tester.tap(find.text('Nächste Seite'));
      await tester.pumpAndSettle();
      expect(find.text('Entry 40'), findsOneWidget);
      expect(find.text('Entry 0'), findsNothing);
    },
  );
}
