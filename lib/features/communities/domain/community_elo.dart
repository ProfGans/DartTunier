import 'dart:math';
import '../../tournaments/application/player_withdrawal_service.dart';

import '../../tournaments/domain/tournament_models.dart';
import 'community.dart';
import 'community_ranking.dart';
import 'community_member_identity.dart';
import 'community_ranking_action.dart';

const int communityInitialElo = 1000;
const int communityEloKFactor = 32;

int communityEloDelta(int rating, int opponentRating, double score) {
  final expected = 1 / (1 + pow(10, (opponentRating - rating) / 400));
  return (communityEloKFactor * (score - expected)).round();
}

class CommunityEloEntry {
  CommunityEloEntry({required this.player, this.rating = communityInitialElo});
  final CommunityMember player;
  int rating;
  int matches = 0;
  int wins = 0;
  int losses = 0;
  int draws = 0;
}

class CommunityEloHistoryItem {
  const CommunityEloHistoryItem({
    required this.playedAt,
    required this.tournamentName,
    required this.opponentName,
    required this.score,
    required this.delta,
    required this.ratingAfter,
  });
  final DateTime playedAt;
  final String tournamentName;
  final String opponentName;
  final String score;
  final int delta;
  final int ratingAfter;
}

class CommunityEloSnapshot {
  const CommunityEloSnapshot({
    required this.entries,
    required this.history,
    this.excludedPlayerKeys = const {},
  });
  final List<CommunityEloEntry> entries;
  final Map<String, List<CommunityEloHistoryItem>> history;
  final Set<String> excludedPlayerKeys;
}

/// Standard Elo expected-score formula with K=32 for community matches.
class CommunityEloCalculator {
  const CommunityEloCalculator();

  CommunityEloSnapshot calculate({
    required List<CommunityMember> members,
    required List<CreatedTournament> tournaments,
    required bool currentYearOnly,
    DateTime? now,
    int? validityMonths,
    String rankingId = defaultCommunityRankingId,
    List<CommunityRankingAction> actions = const [],
  }) {
    final cutoff = validityMonths == null ? null : rankingCutoff((now ?? DateTime.now()).toLocal(), validityMonths);
    final cutoffYear = (now ?? DateTime.now()).toLocal().year;
    final entries = <String, CommunityEloEntry>{
      for (final member in effectiveCommunityMembers(members))
        _idForMember(member): CommunityEloEntry(player: member),
    };
    final aliases = <String, String>{
      for (final entry in entries.entries)
        for (final alias in entry.value.player.aliasProfileIds)
          alias: entry.key,
    };
    final history = <String, List<CommunityEloHistoryItem>>{};
    final excluded = <String>{};
    final ordered =
        {
          for (final tournament in tournaments) tournament.id: tournament,
        }.values.toList()..sort((a, b) {
          final time = a.createdAt.compareTo(b.createdAt);
          return time != 0 ? time : a.id.compareTo(b.id);
        });
    final pending = [
      for (final tournament in ordered)
        if (tournament.countsForRanking &&
            tournament.communityRankingIds.contains(rankingId) &&
            (validityMonths != null || !currentYearOnly ||
                tournament.createdAt.toLocal().year == cutoffYear))
          for (final match in _matches(tournament).toSet())
            if (cutoff == null || !(match.finishedAt ?? tournament.createdAt).toLocal().isBefore(cutoff))
              (tournament: tournament, match: match),
    ];
    // Elo is sequential: use the actual completion order, not bracket/group
    // order. Keep a stable legacy fallback for results without timestamps.
    final legacyOrder = {
      for (var i = 0; i < pending.length; i++) pending[i]: i,
    };
    pending.sort((a, b) {
      final time = (a.match.finishedAt ?? a.tournament.createdAt).compareTo(
        b.match.finishedAt ?? b.tournament.createdAt,
      );
      return time != 0 ? time : legacyOrder[a]!.compareTo(legacyOrder[b]!);
    });
    final changes = actions.where((a) => a.rankingId == rankingId).toList()
      ..sort((a, b) {
        final time = a.createdAt.compareTo(b.createdAt);
        return time == 0 ? a.id.compareTo(b.id) : time;
      });
    // Replay completed matches chronologically in each administration interval.
    // Old results are replayed before a reset, never erased globally.
    for (final change in <CommunityRankingAction?>[...changes, null]) {
      final batch = pending
          .where(
            (row) =>
                change == null ||
                !(row.match.finishedAt ?? row.tournament.createdAt).isAfter(
                  change.createdAt,
                ),
          )
          .toList();
      pending.removeWhere(
        (row) =>
            change == null ||
            !(row.match.finishedAt ?? row.tournament.createdAt).isAfter(
              change.createdAt,
            ),
      );
      for (final row in batch) {
        final tournament = row.tournament;
        final match = row.match;
        if (match.withdrawalIgnored && !match.withdrawalHadResult) continue;
        if (!match.hasResult ||
            match.homePlayer == null ||
            match.awayPlayer == null ||
            match.homePlayer!.bot != null ||
            match.awayPlayer!.bot != null) {
          continue;
        }
        final homeKey = _idForPlayer(match.homePlayer!);
        final awayKey = _idForPlayer(match.awayPlayer!);
        final homeId = aliases[homeKey] ?? homeKey;
        final awayId = aliases[awayKey] ?? awayKey;
        if (excluded.contains(homeId) || excluded.contains(awayId)) continue;
        if (homeId == awayId) continue;
        final home = entries[homeId];
        final away = entries[awayId];
        if (home == null || away == null) continue;
        final homeWon = match.winner == match.homePlayer;
        final awayWon = match.winner == match.awayPlayer;
        final draw = !homeWon && !awayWon && match.homeScore == match.awayScore;
        if (!homeWon && !awayWon && !draw) continue;
        final homeDelta = communityEloDelta(
          home.rating,
          away.rating,
          draw
              ? .5
              : homeWon
              ? 1
              : 0,
        );
        final awayDelta = -homeDelta;
        final homeRule = PlayerWithdrawalService.policy(
          tournament,
          match.homePlayer!,
        );
        final awayRule = PlayerWithdrawalService.policy(
          tournament,
          match.awayPlayer!,
        );
        final countHome =
            (homeRule?.countForRanking ?? true) &&
            (awayRule?.countOpponentsForRanking ?? true);
        final countAway =
            (awayRule?.countForRanking ?? true) &&
            (homeRule?.countOpponentsForRanking ?? true);
        if (countHome) {
          home.rating += homeDelta;
          home.matches++;
        }
        if (countAway) {
          away.rating += awayDelta;
          away.matches++;
        }
        if (draw) {
          if (countHome) home.draws++;
          if (countAway) away.draws++;
        } else if (homeWon) {
          if (countHome) home.wins++;
          if (countAway) away.losses++;
        } else {
          if (countAway) away.wins++;
          if (countHome) home.losses++;
        }
        final score = match.scoreLabel;
        if (countHome) {
          (history[homeId] ??= []).add(
            CommunityEloHistoryItem(
              playedAt: match.finishedAt ?? tournament.createdAt,
              tournamentName: tournament.name,
              opponentName: away.player.displayName,
              score: score,
              delta: homeDelta,
              ratingAfter: home.rating,
            ),
          );
        }
        if (countAway) {
          (history[awayId] ??= []).add(
            CommunityEloHistoryItem(
              playedAt: match.finishedAt ?? tournament.createdAt,
              tournamentName: tournament.name,
              opponentName: home.player.displayName,
              score:
                  '${match.awayScore}:${match.homeScore}${match.hasSetScore ? ' Sets' : ''}',
              delta: awayDelta,
              ratingAfter: away.rating,
            ),
          );
        }
      }
      if (change != null) {
        final key = aliases[change.playerKey] ?? change.playerKey;
        if (change.action == RankingPlayerAction.remove) {
          excluded.add(key);
        } else {
          excluded.remove(key);
          final entry = entries[key];
          if (entry != null) {
            entries[key] = CommunityEloEntry(player: entry.player);
          }
          history.remove(key);
        }
      }
    }
    final result =
        entries.values
            .where(
              (entry) =>
                  entry.matches > 0 &&
                  !excluded.contains(_idForMember(entry.player)),
            )
            .toList()
          ..sort((a, b) => b.rating.compareTo(a.rating));
    return CommunityEloSnapshot(
      entries: result,
      history: history,
      excludedPlayerKeys: excluded,
    );
  }

  String _idForMember(CommunityMember member) =>
      member.playerProfileId ?? member.displayName;
  String _idForPlayer(TournamentPlayer player) =>
      player.profileId ?? player.name;
  Iterable<GroupMatch> _matches(CreatedTournament tournament) sync* {
    for (final stage in tournament.runStages) {
      if (stage is KnockoutTournamentRunStage) yield* stage.matches;
      if (stage is GroupTournamentRunStage) {
        for (final group in stage.groups) {
          yield* group.matches;
        }
      }
    }
  }
}
