import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_tournament_manager/features/communities/domain/community_permissions.dart';
import 'package:dart_tournament_manager/features/communities/domain/community_tournament_access.dart';
import 'package:dart_tournament_manager/features/tournaments/data/tournament_storage.dart';
import 'package:dart_tournament_manager/features/tournaments/domain/tournament_models.dart';

void main() {
  test('role administrators can only delegate their own rights', () {
    final rights = CommunityPermissions(['manage_roles', 'invite_members']);
    expect(rights.mayGrant(['invite_members']), isTrue);
    expect(rights.mayGrant(['delete_tournaments']), isFalse);
    expect(
      CommunityPermissions(['invite_members']).mayGrant(['invite_members']),
      isFalse,
    );
  });
  test('configuration, progress and creation require distinct rights', () {
    final original = {
      'id': 't',
      'communityId': 'g',
      'name': 'Test',
      'runStages': [],
      'activeStageIndex': 0,
    };
    expect(requiredTournamentPermissions(null, original), {
      CommunityPermission.createTournaments,
    });
    expect(
      requiredTournamentPermissions(original, {...original, 'name': 'New'}),
      {CommunityPermission.editTournaments},
    );
    expect(
      requiredTournamentPermissions(original, {
        ...original,
        'activeStageIndex': 1,
      }),
      {CommunityPermission.leadTournaments},
    );
    expect(
      requiredTournamentPermissions(original, {
        ...original,
        'updatedAt': 'now',
      }),
      isEmpty,
    );
    expect(
      () => requiredTournamentPermissions(original, {
        ...original,
        'communityId': null,
      }),
      throwsStateError,
    );
  });
  test('denied offline edits do not replace the saved tournament', () async {
    final directory = await Directory.systemTemp.createTemp('permissions');
    addTearDown(() => directory.delete(recursive: true));
    final grants = {CommunityPermission.createTournaments};
    final store = TournamentStorage(
      file: File('${directory.path}/tournaments.json'),
      currentUserId: () => 'member',
      authorize: (_, permission) async {
        if (!grants.contains(permission)) throw StateError('denied');
      },
    );
    final tournament = CreatedTournament(
      name: 'Original',
      communityId: 'group',
      players: [],
      stages: [],
      runStages: [],
    );
    await store.saveTournament(tournament);
    final changed = CreatedTournament.fromJson(
      tournament.toJson()..['name'] = 'Changed',
    );
    await expectLater(store.saveTournament(changed), throwsStateError);
    expect((await store.loadTournaments()).single.name, 'Original');
    grants.add(CommunityPermission.editTournaments);
    await store.saveTournament(changed);
    expect((await store.loadTournaments()).single.name, 'Changed');
    // Remote deletion wins over an old device's pending offline edits.
    expect(
      await store.communityTournaments('group', [], {tournament.id}),
      isEmpty,
    );
    expect(await store.loadTournaments(), isEmpty);
  });
}
