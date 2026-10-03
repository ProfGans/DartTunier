import '../../tournaments/domain/tournament_models.dart';
import '../domain/community.dart';
import '../domain/community_elo.dart';
import '../domain/community_member_identity.dart';
import '../domain/community_ranking_action.dart';

class CommunityLiveRankingEntry {
  const CommunityLiveRankingEntry({
    required this.entry,
    required this.position,
    required this.previousPosition,
    required this.eloChange,
    required this.participating,
  });
  final CommunityEloEntry entry;
  final int position, eloChange;
  final int? previousPosition;
  final bool participating;
  int? get positionChange =>
      previousPosition == null ? null : previousPosition! - position;
}

class CommunityLiveRanking {
  const CommunityLiveRanking();
  List<CommunityLiveRankingEntry> calculate({
    required CreatedTournament tournament,
    required List<CreatedTournament> tournaments,
    required List<CommunityMember> members,
    required String rankingId,
    required bool currentYearOnly,
    List<CommunityRankingAction> actions = const [],
    DateTime? now,
  }) {
    if (tournament.communityId == null ||
        !tournament.countsForRanking ||
        !tournament.communityRankingIds.contains(rankingId)) {
      return [];
    }
    final others = {
      for (final t in tournaments)
        if (t.communityId == tournament.communityId && t.id != tournament.id)
          t.id: t,
    }.values.toList();
    List<CommunityEloEntry> evaluate(List<CreatedTournament> values) =>
        const CommunityEloCalculator()
            .calculate(
              members: members,
              tournaments: values,
              currentYearOnly: currentYearOnly,
              rankingId: rankingId,
              actions: actions,
              now: now,
            )
            .entries
          ..sort((a, b) {
            final rating = b.rating.compareTo(a.rating);
            return rating != 0
                ? rating
                : _id(a.player).compareTo(_id(b.player));
          });
    final before = evaluate(others);
    final live = evaluate([...others, tournament]);
    Map<String, int> positions(List<CommunityEloEntry> entries) {
      final result = <String, int>{};
      var place = 0;
      for (var i = 0; i < entries.length; i++) {
        if (i == 0 || entries[i].rating != entries[i - 1].rating) place = i + 1;
        result[_id(entries[i].player)] = place;
      }
      return result;
    }

    final previousPositions = positions(before),
        currentPositions = positions(live);
    final ratings = {for (final e in before) _id(e.player): e.rating};
    final identities = {
      for (final member in effectiveCommunityMembers(members))
        for (final alias in member.aliasProfileIds) alias: _id(member),
    };
    final participants = {
      for (final p in tournament.players.expand((p) => p.individuals))
        identities[p.profileId ?? p.name] ?? p.profileId ?? p.name,
    };
    return [
      for (final entry in live)
        CommunityLiveRankingEntry(
          entry: entry,
          position: currentPositions[_id(entry.player)]!,
          previousPosition: previousPositions[_id(entry.player)],
          eloChange:
              entry.rating -
              (ratings[_id(entry.player)] ?? communityInitialElo),
          participating: participants.contains(_id(entry.player)),
        ),
    ];
  }

  String _id(CommunityMember member) =>
      member.playerProfileId ?? member.displayName;
}
