import 'package:flutter_test/flutter_test.dart';
import 'package:dart_tournament_manager/features/communities/domain/community.dart';
import 'package:dart_tournament_manager/features/communities/domain/community_elo.dart';
import 'package:dart_tournament_manager/features/communities/domain/community_member_identity.dart';
import 'package:dart_tournament_manager/features/tournaments/domain/tournament_models.dart';

CommunityMember account(String id) => CommunityMember(
  userId: id,
  playerProfileId: id,
  displayName: id,
  role: 'member',
  joinedAt: DateTime(2026),
);
CommunityMember guest(String? target) => CommunityMember(
  userId: null,
  playerProfileId: 'guest',
  displayName: 'Gast',
  role: 'member',
  joinedAt: DateTime(2026),
  linkedUserId: target,
);

void main() {
  test('manual identity survives linking, reassignment and unlinking', () {
    for (final target in [null, 'a', 'b']) {
      final members = effectiveCommunityMembers([
        account('a'),
        account('b'),
        guest(target),
      ]);
      expect(members.length, target == null ? 3 : 2);
      if (target == null) {
        expect(members.last.playerProfileId, 'guest');
      } else {
        expect(members.singleWhere((m) => m.userId == target).aliasProfileIds, [
          'guest',
        ]);
      }
    }
    expect(
      effectiveCommunityMembers([guest('missing')]).single.playerProfileId,
      'guest',
    );
  });

  test(
    'historical guest results follow the assigned account without duplicates',
    () {
      const home = TournamentPlayer(
        profileId: 'guest',
        name: 'Gast',
        isGenerated: false,
      );
      const away = TournamentPlayer(
        profileId: 'opponent',
        name: 'Gegner',
        isGenerated: false,
      );
      final tournament = CreatedTournament(
        name: 'Test',
        createdAt: DateTime(2026),
        players: const [home, away],
        stages: const [],
        runStages: [
          GroupTournamentRunStage(
            name: 'Gruppe',
            groupPlayType: 'round_robin',
            qualificationPlan: null,
            tieBreakers: const [],
            groups: [
              TournamentGroup(
                name: 'A',
                playType: 'round_robin',
                players: const [home, away],
                matches: [
                  GroupMatch(
                    homePlayer: home,
                    awayPlayer: away,
                    round: 1,
                    homeLegs: 3,
                    awayLegs: 1,
                  ),
                ],
              ),
            ],
          ),
        ],
      );
      for (final target in [null, 'a', 'b']) {
        final snapshot = const CommunityEloCalculator().calculate(
          members: [
            account('a'),
            account('b'),
            account('opponent'),
            guest(target),
          ],
          tournaments: [tournament],
          currentYearOnly: false,
        );
        final winnerId = target ?? 'guest';
        expect(
          snapshot.entries
              .singleWhere((e) => e.player.playerProfileId == winnerId)
              .rating,
          1016,
        );
        expect(snapshot.entries.fold<int>(0, (sum, e) => sum + e.matches), 2);
        expect(snapshot.history[winnerId], hasLength(1));
      }
      final self = const CommunityEloCalculator().calculate(
        members: [account('opponent'), guest('opponent')],
        tournaments: [tournament],
        currentYearOnly: false,
      );
      expect(self.entries.single.rating, 1000);
      expect(self.entries.single.matches, 0);
    },
  );
}
