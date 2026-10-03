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
    final idle = CommunityMember(userId: 'c', playerProfileId: 'c', displayName: 'Charlie', role: 'member', joinedAt: DateTime(2026));
    final snapshot = const CommunityEloCalculator().calculate(members: [alice, bob, idle], tournaments: [tournament], currentYearOnly: true, now: DateTime(2026));
    expect(snapshot.entries.map((entry) => entry.player.displayName), ['Alice', 'Bob']);
    expect(snapshot.entries.first.rating, 1016);
    expect(snapshot.entries.last.rating, 984);
    final excluded = CreatedTournament.fromJson(tournament.toJson()..['countsForRanking'] = false);
    expect(CreatedTournament.fromJson(excluded.toJson()).countsForRanking, isFalse);
    expect(CreatedTournament.fromJson(tournament.toJson()).countsForRanking, isTrue);
    final unranked = const CommunityEloCalculator().calculate(members: [alice, bob], tournaments: [excluded], currentYearOnly: false);
    expect(unranked.entries, isEmpty);
    expect(unranked.history, isEmpty);
    final mixed = const CommunityEloCalculator().calculate(members: [alice, bob], tournaments: [excluded, tournament], currentYearOnly: false);
    expect(mixed.entries.first.rating, 1016);
    expect(mixed.entries.first.matches, 1);
    expect(mixed.history['a'], hasLength(1));
    final custom = CreatedTournament.fromJson(tournament.toJson()..['communityRankingIds'] = ['training']);
    expect(custom.communityRankingIds, ['training']);
    expect(CreatedTournament.fromJson(custom.toJson()).communityRankingIds, ['training']);
    expect(const CommunityEloCalculator().calculate(members: [alice, bob], tournaments: [custom], currentYearOnly: false).entries, isEmpty);
    final training = const CommunityEloCalculator().calculate(members: [alice, bob], tournaments: [custom, tournament], currentYearOnly: false, rankingId: 'training');
    expect(training.entries.first.rating, 1016);
    expect(training.entries.first.matches, 1);
    final shared = CreatedTournament.fromJson(tournament.toJson()..['communityRankingIds'] = ['default', 'training']);
    for (final rank in ['default', 'training']) {
      expect(const CommunityEloCalculator().calculate(members: [alice, bob], tournaments: [shared], currentYearOnly: false, rankingId: rank).entries.first.matches, 1);
    }
    expect(const CommunityEloCalculator().calculate(members: [alice, bob, idle], tournaments: [], currentYearOnly: false).entries, isEmpty);
    expect(const CommunityEloCalculator().calculate(members: [alice, bob, idle], tournaments: [tournament], currentYearOnly: true, now: DateTime(2027)).entries, isEmpty);
    expect(const CommunityEloCalculator().calculate(members: [alice, bob, idle], tournaments: [tournament], currentYearOnly: false, now: DateTime(2027)).entries, hasLength(2));
  });
}
