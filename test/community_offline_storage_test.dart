import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:dart_tournament_manager/features/tournaments/application/tournament_run_controller.dart';
import 'package:dart_tournament_manager/features/tournaments/data/tournament_storage.dart';
import 'package:dart_tournament_manager/features/tournaments/domain/tournament_models.dart';

void main() {
  test('only completion uploads, and only the completed tournament', () async {
    final directory = await Directory.systemTemp.createTemp('completion_sync');
    addTearDown(() => directory.delete(recursive: true));
    final uploaded = <Map<String, dynamic>>[];
    final storage = TournamentStorage(
      file: File('${directory.path}/tournaments.json'),
      currentUserId: () => 'owner',
      upload: (row) async => uploaded.add(row),
    );
    CreatedTournament create(String id) => CreatedTournament(
      id: id, name: id, communityId: 'community', players: const [],
      stages: const [],
      runStages: [for (var i = 0; i < 2; i++) GroupTournamentRunStage(
        name: 'Stage $i', groupPlayType: 'round_robin',
        qualificationPlan: null, tieBreakers: const [], groups: [],
      )],
    );
    final tournament = create('finished');
    await storage.saveTournament(create('ongoing'));
    await storage.saveTournament(tournament);
    expect(uploaded, isEmpty);
    final controller = TournamentRunController(storage: storage);
    await controller.saveProgress(tournament: tournament,
      activeStageIndex: 1, completedStageIndexes: {0});
    expect(uploaded, isEmpty);
    await controller.saveProgress(tournament: tournament,
      activeStageIndex: 1, completedStageIndexes: {0, 1});
    expect(uploaded.single['client_tournament_id'], 'finished');
    uploaded.clear();
    await controller.saveProgress(tournament: tournament,
      activeStageIndex: 1, completedStageIndexes: {0, 1});
    expect(uploaded, isEmpty);
    await storage.synchronize();
    expect(uploaded.map((row) => row['client_tournament_id']),
      unorderedEquals(['ongoing', 'finished']));
  });

  test('offline edits survive restart and upload after reconnection', () async {
    final directory = await Directory.systemTemp.createTemp(
      'community_offline',
    );
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/tournaments.json');
    final storage = TournamentStorage(
      file: file,
      currentUserId: () => 'owner',
      upload: (_) async => throw const SocketException('offline'),
    );
    final tournament = CreatedTournament(
      name: 'Offline',
      createdAt: DateTime(2026),
      communityId: 'community',
      players: const [],
      stages: const [],
      runStages: const [],
    );
    await storage.saveTournament(tournament);
    await storage.synchronize();
    final uploaded = <Map<String, dynamic>>[];
    final restarted = TournamentStorage(
      file: file,
      currentUserId: () => 'owner',
      upload: (row) async => uploaded.add(row),
    );
    final stale = CreatedTournament.fromJson(
      tournament.toJson()..['name'] = 'Old',
    );
    final local = await restarted.communityTournaments('community', [stale]);
    expect(local.single.name, 'Offline');
    await restarted.synchronize();
    expect(uploaded.single['payload']['name'], 'Offline');
    await restarted.synchronize();
    expect(uploaded, hasLength(1));
  });

  test('cached community lists are scoped to the signed in account', () async {
    final directory = await Directory.systemTemp.createTemp('community_cache');
    addTearDown(() => directory.delete(recursive: true));
    var user = 'a';
    final storage = TournamentStorage(
      file: File('${directory.path}/tournaments.json'),
      currentUserId: () => user,
    );
    await storage.writeCache('communities', [
      {'id': 'group'},
    ]);
    user = 'b';
    expect(await storage.readCache('communities'), isNull);
    user = 'a';
    expect((await storage.readCache('communities'))!.single['id'], 'group');
  });
}
