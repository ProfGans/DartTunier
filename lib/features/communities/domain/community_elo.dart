import 'dart:math';

import '../../tournaments/domain/tournament_models.dart';
import 'community.dart';

const int communityInitialElo = 1000;
const int communityEloKFactor = 32;

class CommunityEloEntry {
  CommunityEloEntry({required this.player, this.rating = communityInitialElo});
  final CommunityMember player;
  int rating;
  int matches = 0;
  int wins = 0;
  int losses = 0;
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
  const CommunityEloSnapshot({required this.entries, required this.history});
  final List<CommunityEloEntry> entries;
  final Map<String, List<CommunityEloHistoryItem>> history;
}

/// Standard Elo expected-score formula with K=32 for community matches.
class CommunityEloCalculator {
  const CommunityEloCalculator();

  CommunityEloSnapshot calculate({
    required List<CommunityMember> members,
    required List<CreatedTournament> tournaments,
    required bool currentYearOnly,
    DateTime? now,
  }) {
    final cutoffYear = (now ?? DateTime.now()).year;
    final entries = <String, CommunityEloEntry>{
      for (final member in members) _idForMember(member): CommunityEloEntry(player: member),
    };
    final history = <String, List<CommunityEloHistoryItem>>{};
    final ordered = [...tournaments]..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    for (final tournament in ordered) {
      if (currentYearOnly && tournament.createdAt.year != cutoffYear) continue;
      for (final match in _matches(tournament)) {
        if (!match.hasResult || match.homePlayer == null || match.awayPlayer == null) continue;
        final homeId = _idForPlayer(match.homePlayer!);
        final awayId = _idForPlayer(match.awayPlayer!);
        final home = entries[homeId];
        final away = entries[awayId];
        if (home == null || away == null) continue;
        final homeWon = match.homeLegs! > match.awayLegs!;
        final awayWon = match.awayLegs! > match.homeLegs!;
        if (!homeWon && !awayWon) continue;
        final expectedHome = 1 / (1 + pow(10, (away.rating - home.rating) / 400));
        final expectedAway = 1 - expectedHome;
        final homeDelta = (communityEloKFactor * ((homeWon ? 1 : 0) - expectedHome)).round();
        final awayDelta = (communityEloKFactor * ((awayWon ? 1 : 0) - expectedAway)).round();
        home.rating += homeDelta;
        away.rating += awayDelta;
        home.matches++; away.matches++;
        if (homeWon) { home.wins++; away.losses++; } else { away.wins++; home.losses++; }
        final score = '${match.homeLegs}:${match.awayLegs}';
        (history[homeId] ??= []).add(CommunityEloHistoryItem(playedAt: tournament.createdAt, tournamentName: tournament.name, opponentName: away.player.displayName, score: score, delta: homeDelta, ratingAfter: home.rating));
        (history[awayId] ??= []).add(CommunityEloHistoryItem(playedAt: tournament.createdAt, tournamentName: tournament.name, opponentName: home.player.displayName, score: '${match.awayLegs}:${match.homeLegs}', delta: awayDelta, ratingAfter: away.rating));
      }
    }
    final result = entries.values.toList()..sort((a, b) => b.rating.compareTo(a.rating));
    return CommunityEloSnapshot(entries: result, history: history);
  }

  String _idForMember(CommunityMember member) => member.playerProfileId ?? member.displayName;
  String _idForPlayer(TournamentPlayer player) => player.profileId ?? player.name;
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
