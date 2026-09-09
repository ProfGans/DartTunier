import 'package:flutter_test/flutter_test.dart';
import 'package:dart_tournament_manager/features/communities/domain/community.dart';
import 'package:dart_tournament_manager/features/communities/domain/community_elo.dart';
import 'package:dart_tournament_manager/features/tournaments/domain/tournament_models.dart';

void main() {
  test('starts members at 1000 and applies zero-sum standard Elo', () {
    final alice = CommunityMember(userId: 'a', playerProfileId: 'a', displayName: 'Alice', role: 'member', joinedAt: DateTime(2026));
    final bob = CommunityMember(userId: 'b', playerProfileId: 'b', displayName: 'Bob', role: 'member', joinedAt: DateTime(2026));
    final tournament = CreatedTournament(
      name: 'Test', createdAt: DateTime(2026, 2), players: const [TournamentPlayer(profileId: 'a', name: 'Alice', isGenerated: false), TournamentPlayer(profileId: 'b', name: 'Bob', isGenerated: false)], stages: const [],
      runStages: [GroupTournamentRunStage(name: 'Gruppe', groupPlayType: 'round_robin', qualificationPlan: null, tieBreakers: const [], groups: [TournamentGroup(name: 'A', playType: 'round_robin', players: const [], matches: [GroupMatch(homePlayer: const TournamentPlayer(profileId: 'a', name: 'Alice', isGenerated: false), awayPlayer: const TournamentPlayer(profileId: 'b', name: 'Bob', isGenerated: false), round: 1, homeLegs: 3, awayLegs: 1)])])],
    );
    final snapshot = const CommunityEloCalculator().calculate(members: [alice, bob], tournaments: [tournament], currentYearOnly: true, now: DateTime(2026));
    expect(snapshot.entries.first.rating, 1016);
    expect(snapshot.entries.last.rating, 984);
  });
}
