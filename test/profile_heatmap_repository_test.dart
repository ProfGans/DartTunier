import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_tournament_manager/features/tournaments/data/app_database.dart';
import 'package:dart_tournament_manager/features/statistics/data/profile_heatmap_repository.dart';
import 'package:dart_tournament_manager/features/statistics/data/scorer_heatmap_repository.dart';
import 'package:dart_tournament_manager/features/scorer/domain/scorer_hit.dart';
import 'package:dart_tournament_manager/features/statistics/domain/heatmap_analysis.dart';

void main() {
  ScorerHit hit(int player, String label) => ScorerHit(
    location: const DartLocation(0, -166),
    player: player,
    leg: 1,
    thrower: 'Spieler',
    label: label,
    points: 40,
    checkoutAttempt: true,
    targetLabel: 'D20',
    dartInVisit: 2,
    visitIndex: 3,
    thrownAt: DateTime.utc(2026, 10, 8),
  );
  ScorerHeatmapSession session(List<ScorerHit> hits) => ScorerHeatmapSession(
    id: 'match',
    date: DateTime.utc(2026, 10, 8),
    names: const ['A', 'B'],
    hits: hits,
    complete: false,
  );
  test(
    'private offline queue survives restart, upload and empty undo',
    () async {
      final dir = await Directory.systemTemp.createTemp('heatmap_owner_');
      addTearDown(() => dir.delete(recursive: true));
      final db = LocalAppDatabase(baseDirectory: dir);
      final remote = <Map<String, dynamic>>[];
      var offline = true;
      ProfileHeatmapRepository repo() => ProfileHeatmapRepository(
        database: db,
        currentUserId: () => 'owner',
        upload: (row) async {
          if (offline) throw StateError('offline');
          remote
            ..clear()
            ..add(row);
        },
        download: (_) async => remote,
      );
      final first = repo();
      await first.save('owner', session([hit(0, 'D20'), hit(1, 'D5')]), 0);
      await first.synchronize('owner');
      final restarted = repo();
      expect((await restarted.load('owner')).single.hits.single.player, 0);
      expect(await restarted.load('other'), isEmpty);
      offline = false;
      await restarted.synchronize('owner');
      expect(remote, hasLength(1));
      expect(restarted.status, 'Heatmaps synchronisiert');
      final secondDevice = ProfileHeatmapRepository(
        database: LocalAppDatabase(
          baseDirectory: Directory('${dir.path}/device2'),
        ),
        currentUserId: () => 'owner',
        upload: (_) async {},
        download: (_) async => remote,
      );
      await secondDevice.synchronize('owner');
      expect(
        (await secondDevice.load('owner')).single.hits.single.targetLabel,
        'D20',
      );
      await restarted.save('owner', session([]), 0);
      await restarted.synchronize('owner');
      expect((remote.single['payload'] as Map)['hits'], isEmpty);
      expect((await restarted.load('owner')).single.hits, isEmpty);
      await secondDevice.synchronize('owner');
      expect((await secondDevice.load('owner')).single.hits, isEmpty);
    },
  );
  test(
    'an edit during upload remains pending and wins over old download',
    () async {
      final dir = await Directory.systemTemp.createTemp('heatmap_race_');
      addTearDown(() => dir.delete(recursive: true));
      final remote = <Map<String, dynamic>>[];
      var changeDuringUpload = true;
      late ProfileHeatmapRepository repo;
      repo = ProfileHeatmapRepository(
        database: LocalAppDatabase(baseDirectory: dir),
        currentUserId: () => 'owner',
        upload: (row) async {
          remote
            ..clear()
            ..add(row);
          if (changeDuringUpload) {
            changeDuringUpload = false;
            await repo.save('owner', session([hit(0, 'D20'), hit(0, 'D5')]), 0);
          }
        },
        download: (_) async => remote,
      );
      await repo.save('owner', session([hit(0, 'D20')]), 0);
      await repo.synchronize('owner');
      expect((await repo.load('owner')).single.hits, hasLength(2));
      expect(repo.status, contains('ausstehend'));
      await repo.synchronize('owner');
      expect((remote.single['payload'] as Map)['hits'], hasLength(2));
      expect(repo.status, 'Heatmaps synchronisiert');
    },
  );
  test(
    'wrong account cannot upload; explicit targets roundtrip and filter',
    () async {
      final dir = await Directory.systemTemp.createTemp('heatmap_account_');
      addTearDown(() => dir.delete(recursive: true));
      var uploads = 0;
      final repo = ProfileHeatmapRepository(
        database: LocalAppDatabase(baseDirectory: dir),
        currentUserId: () => 'other',
        upload: (_) async {
          uploads++;
        },
        download: (_) async => [],
      );
      await repo.save('owner', session([hit(0, 'D20')]), 0);
      await repo.synchronize('owner');
      expect(uploads, 0);
      final restored = ScorerHit.fromJson(hit(0, 'D20').toJson());
      expect(restored.thrownAt, DateTime.utc(2026, 10, 8));
      expect(HeatmapAnalysis.filter([restored], dart: 1), isEmpty);
      expect(
        HeatmapAnalysis.filter([restored], visit: 3, area: 'Training'),
        hasLength(1),
      );
      final result = HeatmapAnalysis.targets([restored]).single;
      expect(result.percent, 100);
      expect(result.meanTargetDistance, closeTo(0, 0.001));
    },
  );
}
