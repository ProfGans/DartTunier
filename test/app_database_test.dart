import 'dart:io';

import 'package:dart_tournament_manager/features/tournaments/data/app_database.dart';
import 'package:dart_tournament_manager/features/tournaments/domain/tournament_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('seeds player profiles and exposes them as tournament players', () async {
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
    expect(profiles, hasLength(4));
    expect(
      profiles.map((profile) => profile.displayName),
      containsAll([
        'Luke Littler',
        'Michael van Gerwen',
        'Gerwyn Price',
        'Fallon Sherrock',
      ]),
    );
    expect(players.map((player) => player.name), [
      'Fallon Sherrock',
      'Gerwyn Price',
      'Luke Littler',
      'Michael van Gerwen',
    ]);
    expect(players.map((player) => player.profileId), [
      '00000000-0000-4000-8000-000000000104',
      '00000000-0000-4000-8000-000000000103',
      '00000000-0000-4000-8000-000000000101',
      '00000000-0000-4000-8000-000000000102',
    ]);
    expect(players.every((player) => !player.isGenerated), isTrue);
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

  test('registers a local account and links a player profile', () async {
    final directory = await Directory.systemTemp.createTemp(
      'dart_tournament_manager_database_test_',
    );
    addTearDown(() => directory.delete(recursive: true));

    final database = LocalAppDatabase(baseDirectory: directory);

    expect(await database.loadCurrentAccount(), isNull);

    final account = await database.registerLocalAccount(
      displayName: 'Theo Checkout',
      email: 'theo@example.local',
    );

    final currentAccount = await database.loadCurrentAccount();
    final profiles = await database.loadPlayerProfiles();

    expect(currentAccount?.id, account.id);
    expect(currentAccount?.displayName, 'Theo Checkout');
    expect(currentAccount?.email, 'theo@example.local');
    expect(
      profiles.where(
        (profile) =>
            profile.userId == account.id &&
            profile.displayName == 'Theo Checkout' &&
            profile.country.isEmpty &&
            profile.city.isEmpty &&
            profile.dartsSetupJson.isEmpty,
      ),
      hasLength(1),
    );
  });

  test('signs in and signs out an existing local account', () async {
    final directory = await Directory.systemTemp.createTemp(
      'dart_tournament_manager_database_test_',
    );
    addTearDown(() => directory.delete(recursive: true));

    final database = LocalAppDatabase(baseDirectory: directory);
    final account = await database.registerLocalAccount(
      displayName: 'Anna Average',
      email: 'anna@example.local',
    );

    await database.signOutCurrentAccount();
    expect(await database.loadCurrentAccount(), isNull);

    final signedIn = await database.signInLocalAccount(
      email: 'ANNA@example.local',
    );

    expect(signedIn?.id, account.id);
    expect((await database.loadCurrentAccount())?.id, account.id);

    await database.signOutCurrentAccount();
    expect(await database.loadCurrentAccount(), isNull);
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
