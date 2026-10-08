import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dart_tournament_manager/features/scorer/application/scorer_controller.dart';
import 'package:dart_tournament_manager/features/scorer/domain/scorer_hit.dart';
import 'package:dart_tournament_manager/features/scorer/domain/scorer_settings.dart';
import 'package:dart_tournament_manager/features/scorer/domain/x01/x01_rules.dart';
import 'package:dart_tournament_manager/features/scorer/domain/x01/x01_models.dart';
import 'package:dart_tournament_manager/features/statistics/data/scorer_heatmap_repository.dart';
import 'package:dart_tournament_manager/features/statistics/presentation/heatmap/scorer_heatmap_page.dart';
import 'package:dart_tournament_manager/features/statistics/presentation/heatmap/scorer_heatmap_view.dart';
import 'package:dart_tournament_manager/features/statistics/domain/scorer_heatmap_summary.dart';

void main() {
  setUpAll(() async {
    if (const bool.fromEnvironment('HEATMAP_PREVIEW')) {
      final loader = FontLoader('HeatmapPreview')
        ..addFont(
          File(
            'C:/Windows/Fonts/segoeui.ttf',
          ).readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
        );
      await loader.load();
    }
  });
  const rules = X01Rules();
  final settings = ScorerSettings(
    participants: const [
      ScorerParticipant('Anna / Ben', members: ['Anna', 'Ben']),
      ScorerParticipant('Chris'),
    ],
  );
  const location = DartLocation(0, -103, estimated: true);
  test(
    'Explicit targets and timestamps survive replay; legacy stays unknown',
    () {
      final c = ScorerController(settings)..intendedTarget = 'T20';
      final time = DateTime.utc(2026, 10, 8, 12);
      c.throwDart(rules.createTriple(20), location: location, thrownAt: time);
      c.throwDart(rules.createSingle(20), location: location, thrownAt: time);
      final restored = ScorerController(settings)
        ..restoreActions(c.exportActions());
      expect(restored.hits.first.targetLabel, 'T20');
      expect(restored.hits.first.thrownAt, time);
      expect(restored.hits.map((h) => h.dartInVisit), [1, 2]);
      restored.undo();
      expect(restored.hits, hasLength(1));
      final legacy = c
          .exportActions()
          .map(
            (action) => Map<String, dynamic>.from(action)
              ..remove('thrownAt')
              ..remove('targetLabel'),
          )
          .toList();
      restored.replaceActions(legacy);
      expect(
        restored.hits.every((h) => h.targetLabel == null && h.thrownAt == null),
        isTrue,
      );
      c.throwDart(rules.createSingle(20), location: location);
      expect(c.intendedTarget, isNull);
      c.dispose();
      restored.dispose();
    },
  );
  test('Physical centroid and RMS use board coordinates', () {
    final c = ScorerController(settings)
      ..throwDart(
        rules.createSingle(20),
        location: const DartLocation(-3, -100),
      )
      ..throwDart(
        rules.createSingle(20),
        location: const DartLocation(3, -100),
      );
    final summary = ScorerHeatmapSummary(c.hits);
    expect(summary.x, 0);
    expect(summary.y, -100);
    expect(summary.spread, 3);
    expect(summary.ranked.single.value, 2);
    c.dispose();
  });
  test(
    'Positions survive replay, corrections and undo with team attribution',
    () {
      final c = ScorerController(settings);
      c.throwDart(rules.createTriple(20), location: location);
      c.throwDart(rules.createMiss());
      c.throwDart(
        rules.createSingle(20),
        location: const DartLocation(0, -120),
      );
      c.submitScore(60);
      c.throwDart(rules.createTriple(20), location: location);
      expect(c.hits.map((h) => h.thrower), ['Anna', 'Anna', 'Ben']);
      final restored = ScorerController(settings)
        ..restoreActions(c.exportActions());
      expect(
        restored.hits.map((h) => h.toJson()),
        c.hits.map((h) => h.toJson()),
      );
      restored.undo();
      expect(restored.hits.length, 2);
      restored.throwDart(
        rules.createDouble(20),
        location: const DartLocation(0, -166, corrected: true),
      );
      c.replaceActions(restored.exportActions());
      expect(c.hits.length, 3);
      expect(c.hits.last.location.corrected, isTrue);
      expect(c.hits.last.label, 'D20');
      c.dispose();
      restored.dispose();
    },
  );
  test(
    'Bust positions remain physical hits; manual totals and bots are excluded',
    () {
      final c = ScorerController(
        ScorerSettings(
          startScore: 40,
          participants: const [
            ScorerParticipant('Anna'),
            ScorerParticipant(
              'Bot',
              bot: BotProfile(skill: 50, finishingSkill: 50),
            ),
          ],
        ),
      );
      c.throwDart(
        rules.createTriple(20),
        location: location,
        checkoutAttempt: true,
      );
      expect(c.hits.single.points, 60);
      expect(c.hits.single.checkoutAttempt, true);
      c.throwDart(rules.createTriple(20), location: location);
      expect(c.hits.length, 1);
      c.submitScore(20);
      expect(c.hits.length, 1);
      c.dispose();
    },
  );
  test(
    'Archive persists positions and flags, replaces sessions and removes undone hits',
    () async {
      SharedPreferences.setMockInitialValues({});
      final c = ScorerController(settings)
        ..throwDart(rules.createTriple(20), location: location);
      final repo = ScorerHeatmapRepository();
      ScorerHeatmapSession entry(List<ScorerHit> hits) => ScorerHeatmapSession(
        id: 'one',
        date: DateTime(2026, 10, 3),
        names: ['Anna', 'Chris'],
        hits: hits,
      );
      await repo.save(entry(c.hits));
      await repo.save(entry(c.hits));
      final saved = await ScorerHeatmapRepository().load();
      expect(saved.length, 1);
      expect(saved.single.hits.single.location.estimated, true);
      expect(saved.single.hits.single.location.y, -103);
      await repo.save(entry([]));
      expect(await repo.load(), isEmpty);
      c.dispose();
    },
  );
  for (final size in [
    const Size(360, 800),
    const Size(800, 600),
    const Size(1440, 900),
  ]) {
    testWidgets('Heatmap and filters at $size with 200 percent text', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final c = ScorerController(settings)
        ..throwDart(rules.createTriple(20), location: location);
      final capture = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          theme: const bool.fromEnvironment('HEATMAP_PREVIEW')
              ? ThemeData(fontFamily: 'HeatmapPreview')
              : null,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: RepaintBoundary(key: capture, child: child!),
          ),
          home: ScorerHeatmapPage(
            sessions: [
              ScorerHeatmapSession(
                id: 'one',
                date: DateTime.now(),
                names: ['Anna / Ben', 'Chris'],
                hits: c.hits,
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      if (const bool.fromEnvironment('HEATMAP_PREVIEW')) {
        await tester.scrollUntilVisible(find.byType(ScorerHeatmapView), 200);
        await Scrollable.ensureVisible(
          tester.element(find.byType(ScorerHeatmapView)),
          alignment: .2,
        );
        await tester.pumpAndSettle();
        final boundary =
            capture.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        await tester.runAsync(() async {
          final image = await boundary.toImage();
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          await Directory('build/heatmap_previews').create(recursive: true);
          await File(
            'build/heatmap_previews/${size.width.toInt()}.png',
          ).writeAsBytes(data!.buffer.asUint8List());
          image.dispose();
        });
        tester
            .state<ScrollableState>(find.byType(Scrollable).first)
            .position
            .jumpTo(0);
        await tester.pumpAndSettle();
      }
      await tester.scrollUntilVisible(
        find.text('Schätzungen einschließen'),
        200,
      );
      await Scrollable.ensureVisible(
        tester.element(find.text('Schätzungen einschließen')),
        alignment: 0.4,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Schätzungen einschließen'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.byType(ScorerHeatmapView), 200);
      expect(
        tester.widget<ScorerHeatmapView>(find.byType(ScorerHeatmapView)).hits,
        isEmpty,
      );
      await tester.scrollUntilVisible(find.text('Getroffene Felder'), 200);
      expect(tester.takeException(), isNull);
      c.dispose();
    });
  }
}
