import '../../tournaments/application/order_of_play/order_of_play_controller.dart';
import '../../tournaments/domain/tournament_models.dart';
import '../domain/community.dart';
import '../domain/community_elo.dart';
import '../domain/community_member_identity.dart';
import '../domain/community_ranking_action.dart';

class TournamentEloPlayer {
  const TournamentEloPlayer({
    required this.player,
    this.rating,
    this.opponent,
    this.win,
    this.loss,
    this.draw,
  });
  final TournamentPlayer player;
  final int? rating;
  final String? opponent;
  final int? win, loss, draw;
}

/// Uses the ranking's identities and replaces its saved copy with live results.
class CommunityTournamentElo {
  const CommunityTournamentElo();

  List<TournamentEloPlayer> calculate({
    required CreatedTournament tournament,
    required List<CreatedTournament> tournaments,
    required List<CommunityMember> members,
    required String rankingId,
    required bool currentYearOnly,
    required int activeStage,
    DateTime? now,
    int? validityMonths,
    List<CommunityRankingAction> actions = const [],
  }) {
    if (tournament.communityId == null ||
        !tournament.countsForRanking ||
        !tournament.communityRankingIds.contains(rankingId)) {
      return [];
    }
    final effective = effectiveCommunityMembers(members);
    final identities = <String, String>{
      for (final member in effective) ...{
        member.playerProfileId ?? member.displayName:
            member.playerProfileId ?? member.displayName,
        for (final alias in member.aliasProfileIds)
          alias: member.playerProfileId ?? member.displayName,
      },
    };
    final snapshot = const CommunityEloCalculator().calculate(
      members: members,
      actions: actions,
      tournaments: [
        ...tournaments.where(
          (t) =>
              t.id != tournament.id && t.communityId == tournament.communityId,
        ),
        tournament,
      ],
      rankingId: rankingId,
      currentYearOnly: currentYearOnly,
      now: now,
      validityMonths: validityMonths,
    );
    final ratings = {
      for (final entry in snapshot.entries)
        entry.player.playerProfileId ?? entry.player.displayName: entry.rating,
    };
    String? identity(TournamentPlayer p) =>
        p.isTeam ? null : identities[p.profileId ?? p.name];
    int? rating(TournamentPlayer p) {
      final id = identity(p);
      return id == null || snapshot.excludedPlayerKeys.contains(id)
          ? null
          : ratings[id] ?? communityInitialElo;
    }

    final schedule = const OrderOfPlayController().plan(
      tournament,
      activeStage,
    );
    final next = <String, PlayEntry>{};
    for (final entry in [
      ...schedule.running,
      ...schedule.planned.map((a) => a.entry),
    ]) {
      for (final p in [entry.match.homePlayer!, entry.match.awayPlayer!]) {
        final id = identity(p);
        if (id != null) next.putIfAbsent(id, () => entry);
      }
    }
    return [
      for (final player in tournament.players)
        (() {
          final value = rating(player);
          final entry = next[identity(player)];
          if (value == null ||
              entry == null ||
              (validityMonths == null && currentYearOnly &&
                  tournament.createdAt.toLocal().year !=
                      (now ?? DateTime.now()).toLocal().year)) {
            return TournamentEloPlayer(player: player, rating: value);
          }
          final home = entry.match.homePlayer!;
          final away = entry.match.awayPlayer!;
          final isHome = identity(home) == identity(player);
          final opponent = isHome ? away : home;
          final other = rating(opponent);
          if (other == null || identity(opponent) == identity(player)) {
            return TournamentEloPlayer(
              player: player,
              rating: value,
              opponent: opponent.name,
            );
          }
          // Derive away deltas from the home calculation, including rounding ties.
          int delta(double score) => isHome
              ? communityEloDelta(value, other, score)
              : -communityEloDelta(other, value, 1 - score);
          final draws =
              entry.stageIndex < tournament.stages.length &&
              tournament.stages[entry.stageIndex].gameFormat.allowsDraws &&
              !entry.match.isDecider &&
              tournament.runStages[entry.stageIndex]
                  is GroupTournamentRunStage &&
              (tournament.runStages[entry.stageIndex]
                      as GroupTournamentRunStage)
                  .groups
                  .any(
                    (g) =>
                        g.knockoutRounds.isEmpty &&
                        g.matches.contains(entry.match),
                  );
          return TournamentEloPlayer(
            player: player,
            rating: value,
            opponent: opponent.name,
            win: delta(1),
            loss: delta(0),
            draw: draws ? delta(.5) : null,
          );
        })(),
    ];
  }
}
