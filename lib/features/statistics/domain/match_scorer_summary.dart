import '../../scorer/domain/scorer_statistics.dart';
import '../../tournaments/domain/tournament_models.dart';
import 'saved_scorer_match.dart';
import 'bot_statistics_privacy.dart';

/// Derived from the persisted visits, never from a manually entered score.
class MatchScorerSummary {
  const MatchScorerSummary(this.players);
  final List<ScorerPlayerStatistics> players;

  static MatchScorerSummary? fromMatch(GroupMatch match) {
    if (!match.countsForStatistics || !match.hasPlayers || match.isAnnulled) return null;
    final raw = withoutBotStatistics(match.deviceResult, {
      if (match.homePlayer?.bot != null) 0,
      if (match.awayPlayer?.bot != null) 1,
    })?['statistics'];
    if (raw is! Map<String, dynamic>) return null;
    try {
      final saved = SavedScorerMatch.fromJson(raw);
      if (saved.names.length != 2 || saved.visits.isEmpty) return null;
      return MatchScorerSummary(
        ScorerStatistics.calculate(
          saved.visits,
          playerCount: 2,
          startScores: saved.startScores,
          standard501Rules: saved.standard501Rules,
        ).players,
      );
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    } on RangeError {
      return null;
    }
  }

  String get averageLabel =>
      'Average: ${players[0].average?.toStringAsFixed(2) ?? '–'} : ${players[1].average?.toStringAsFixed(2) ?? '–'}';
}

class ScorerHighlightPlayer {
  final Map<int, int> maxima = {}, shortLegs = {};
  int get maximumCount => maxima.values.fold(0, (sum, count) => sum + count);
  ScorerHighlightPlayer(this.name, {String? id}) : id = id ?? name;
  final String name;
  final String id;
  int points = 0, darts = 0, matches = 0, scores180 = 0, highestFinish = 0;
  int? bestLeg;
  double? get average => darts == 0 ? null : points * 3 / darts;
}

class TournamentScorerHighlights {
  TournamentScorerHighlights(Iterable<GroupMatch> matches) {
    final rows = <String, ScorerHighlightPlayer>{};
    for (final match in matches.toSet()) {
      if (!match.hasPlayers || !match.countsForStatistics || match.isAnnulled) continue;
      completed++;
      final summary = MatchScorerSummary.fromMatch(match);
      if (summary == null) continue;
      recorded++;
      final sides = [match.homePlayer!, match.awayPlayer!];
      for (var i = 0; i < 2; i++) {
        final player = sides[i];
        if (player.bot != null) continue;
        final row = rows.putIfAbsent(
          player.profileId ?? player.name,
          () => ScorerHighlightPlayer(
            player.name,
            id: player.profileId ?? player.name,
          ),
        );
        final stats = summary.players[i];
        if (stats.darts == 0) continue;
        row.matches++;
        row.points += stats.points;
        row.darts += stats.darts;
        row.scores180 += stats.scores180;
        for (final entry in stats.maxima.entries) {
          row.maxima.update(
            entry.key,
            (count) => count + entry.value,
            ifAbsent: () => entry.value,
          );
        }
        for (final entry in stats.shortLegs.entries) {
          row.shortLegs.update(
            entry.key,
            (count) => count + entry.value,
            ifAbsent: () => entry.value,
          );
        }
        if (stats.highestFinish > row.highestFinish) {
          row.highestFinish = stats.highestFinish;
        }
        if (stats.bestLeg != null &&
            (row.bestLeg == null || stats.bestLeg! < row.bestLeg!)) {
          row.bestLeg = stats.bestLeg;
        }
      }
    }
    players = rows.values.where((p) => p.darts > 0).toList()
      ..sort((a, b) => b.average!.compareTo(a.average!));
  }
  int completed = 0, recorded = 0;
  late final List<ScorerHighlightPlayer> players;
}
