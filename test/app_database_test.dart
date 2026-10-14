import 'dart:io';

import 'package:dart_tournament_manager/features/tournaments/data/app_database.dart';
import 'package:dart_tournament_manager/features/tournaments/domain/tournament_models.dart';
import 'package:dart_tournament_manager/features/rankings/domain/local_ranking.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('starts with an empty player catalog', () async {
    final directory = await Directory.systemTemp.createTemp(
      'dart_tournament_manager_database_test_',
    );
    addTearDown(() => directory.delete(recursive: true));

    final database = LocalAppDatabase(baseDirectory: directory);

    final databaseFile = await database.databaseFile();
    final profiles = await database.loadPlayerProfiles();
    final players = await database.loadTournamentPlayers();

    expect(databaseFile.path.endsWith('app_database.sqlite'), isTrue);
    expect(databaseFile.existsSync(), isTrue);
    expect(profiles, isEmpty);
    expect(players, isEmpty);
  });

  test('creates, updates and deactivates player profiles', () async {
    final directory = await Directory.systemTemp.createTemp(
      'dart_tournament_manager_database_test_',
    );
    addTearDown(() => directory.delete(recursive: true));

    final database = LocalAppDatabase(baseDirectory: directory);

    final created = await database.createPlayerProfile(
      displayName: 'Max Mustermann',
      country: 'Deutschland',
      city: 'Berlin',
      dartsSetupJson: '23g Steeldart',
    );

    var profiles = await database.loadPlayerProfiles();
    expect(
      profiles.where((profile) => profile.displayName == 'Max Mustermann'),
      hasLength(1),
    );

    await database.updatePlayerProfile(
      created.copyWith(
        displayName: 'Max Power',
        city: 'Hamburg',
        dartsSetupJson: '24g Steeldart',
      ),
    );

    profiles = await database.loadPlayerProfiles();
    final updated = profiles.singleWhere(
      (profile) => profile.id == created.id,
    );
    expect(updated.displayName, 'Max Power');
    expect(updated.city, 'Hamburg');
    expect(updated.dartsSetupJson, '24g Steeldart');

    await database.deactivatePlayerProfile(created.id);

    profiles = await database.loadPlayerProfiles();
    expect(profiles.any((profile) => profile.id == created.id), isFalse);
  });

  test('stores local rankings and their assigned player profiles', () async {
    final directory = await Directory.systemTemp.createTemp(
      'dart_local_rankings_test_',
    );
    addTearDown(() => directory.delete(recursive: true));
    final database = LocalAppDatabase(baseDirectory: directory);
    final player = await database.createPlayerProfile(displayName: 'Vereinsdart');
    const ranking = LocalRanking(
      id: 'dc-unzenberg-2026',
      name: 'DC Unzenberg 2026',
      startRating: 1200,
      newPlayerK: 30,
      matchesBeforeNormal: 12,
    );

    await database.saveLocalRanking(ranking);
    await database.setRankingPlayers(ranking.id, [player.id]);

    expect((await database.loadLocalRankings()).single.startRating, 1200);
    expect(await database.loadRankingPlayerIds(ranking.id), [player.id]);
    expect(
      (await database.loadRankingsForPlayer(player.id)).single.name,
      'DC Unzenberg 2026',
    );

    await database.deleteLocalRanking(ranking.id);
    expect(await database.loadRankingPlayerIds(ranking.id), isEmpty);
  });

  test('keeps player profile id in tournament player json', () {
    const player = TournamentPlayer(
      profileId: 'profile-1',
      name: 'Anna Check',
      isGenerated: false,
    );

    final restored = TournamentPlayer.fromJson(player.toJson());

    expect(restored.profileId, 'profile-1');
    expect(restored.name, 'Anna Check');
    expect(restored.isGenerated, isFalse);
  });
}
