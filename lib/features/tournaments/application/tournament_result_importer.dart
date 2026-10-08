import '../../statistics/domain/saved_scorer_match.dart';
import '../../statistics/domain/bot_statistics_privacy.dart';
import 'order_of_play/order_of_play_controller.dart';
import '../domain/tournament_models.dart';
import 'tournament_match_assignment.dart';
import 'dart:convert';

class TournamentResultImporter {
  const TournamentResultImporter({this.requireStatistics = false});
  final bool requireStatistics;
  GroupMatch validate(
    CreatedTournament tournament,
    Map<String, dynamic> result,
  ) {
    try {
      return _validate(tournament, result);
    } on TypeError {
      throw const FormatException('Ungültige Typen im Spielergebnis');
    } on RangeError {
      throw const FormatException('Ungültige Werte im Spielergebnis');
    }
  }

  GroupMatch _validate(
    CreatedTournament tournament,
    Map<String, dynamic> result,
  ) {
    final entry = const OrderOfPlayController()
        .entries(tournament)
        .where(
          (entry) =>
              TournamentMatchAssignment.id(tournament, entry) ==
              result['matchId'],
        )
        .firstOrNull;
    if (entry == null || result['version'] != 1) {
      throw StateError('Veraltete Spielzuweisung');
    }
    final match = entry.match;
    if (match.deviceResult?['matchId'] == result['matchId']) {
      if (_canonical(match.deviceResult) != _canonical(_clean(match, result))) {
        throw StateError('Widersprüchliche erneute Ergebnisübertragung');
      }
      return match;
    }
    if (entry.stageIndex != tournament.activeStageIndex ||
        tournament.completedStageIndexes.contains(entry.stageIndex) ||
        match.isResolved ||
        match.startedAt == null ||
        !match.hasPlayers) {
      throw StateError('Spiel wurde bereits geändert');
    }
    final format = tournament.stages[entry.stageIndex].gameFormat;
    final legs = List<int>.from(result['legs'] as List);
    final sets = List<int>.from(result['sets'] as List);
    if (legs.length != 2 ||
        sets.length != 2 ||
        legs.any((n) => n < 0) ||
        sets.any((n) => n < 0)) {
      throw const FormatException(
        'Erwartet werden jeweils zwei nichtnegative Leg-/Satzwerte',
      );
    }
    final scores = format.bestOfSets > 1 ? sets : legs;
    final win = scores[0] == scores[1]
        ? null
        : scores[0] > scores[1]
        ? 0
        : 1;
    final target =
        (format.bestOfSets > 1 ? format.bestOfSets : format.bestOfLegs) ~/ 2 +
        1;
    final draw =
        format.allowsDraws &&
        win == null &&
        legs[0] == format.bestOfLegs ~/ 2 &&
        sets.every((n) => n == 0) &&
        !match.isDecider;
    if (!draw &&
        (win == null ||
            scores[win] != target ||
            scores[1 - win] >= target ||
            (format.allowsDraws && legs[0] + legs[1] > format.bestOfLegs))) {
      throw const FormatException('Ergebnis passt nicht zum Spielformat');
    }
    if (format.bestOfSets == 1 && sets.any((n) => n != 0)) {
      throw const FormatException('Sätze sind in diesem Spiel nicht aktiviert');
    }
    if (format.bestOfSets > 1) {
      final perSet = format.bestOfLegs ~/ 2 + 1;
      for (var i = 0; i < 2; i++) {
        if (legs[i] < sets[i] * perSet ||
            legs[i] > sets[i] * perSet + sets[1 - i] * (perSet - 1)) {
          throw const FormatException('Legsumme passt nicht zu den Sätzen');
        }
      }
    }
    if (result['statistics'] == null && !requireStatistics) return match;
    final stats = SavedScorerMatch.fromJson(
      result['statistics'] as Map<String, dynamic>,
    );
    if (legs.length != 2 ||
        sets.length != 2 ||
        legs.any((n) => n < 0) ||
        sets.any((n) => n < 0) ||
        stats.names.length != 2 ||
        stats.names[0] != match.homePlayer!.name ||
        stats.names[1] != match.awayPlayer!.name ||
        stats.startScores.length != 2 ||
        stats.startScores.any((n) => n != format.x01Score) ||
        stats.playerIndex != 0 ||
        stats.doubleOut != (format.checkoutType == 'double_out') ||
        ![null, 0, 1].contains(stats.winner) ||
        stats.visits.length > 10000 ||
        stats.visits.any(
          (v) =>
              v.player < 0 ||
              v.player > 1 ||
              v.darts < 1 ||
              v.darts > 3 ||
              v.points < 0 ||
              v.points > 180 ||
              v.remaining < 0,
        )) {
      throw const FormatException('Ungültiges Geräteergebnis');
    }
    if (stats.winner != win) {
      throw const FormatException('Statistik-Sieger passt nicht zum Ergebnis');
    }
    for (var i = 0; i < 2; i++) {
      if ([match.homePlayer, match.awayPlayer][i]?.bot != null) continue;
      final calculated = SavedScorerMatch.fromJson({
        ...stats.toJson(),
        'playerIndex': i,
      }).statistics;
      if (calculated.legsWon != legs[i]) {
        throw const FormatException('Statistik passt nicht zum Ergebnis');
      }
    }
    return match;
  }

  void apply(
    GroupMatch match,
    Map<String, dynamic> result,
    TournamentGameFormat format,
  ) {
    match.homeLegs = (result['legs'] as List)[0] as int;
    match.awayLegs = (result['legs'] as List)[1] as int;
    match.homeSets = format.bestOfSets > 1
        ? (result['sets'] as List)[0] as int
        : null;
    match.awaySets = format.bestOfSets > 1
        ? (result['sets'] as List)[1] as int
        : null;
    match.deviceResult = withoutBotStatistics(result, {
      if (match.homePlayer?.bot != null) 0,
      if (match.awayPlayer?.bot != null) 1,
    });
    const OrderOfPlayController().resultRecorded(match);
  }

  Map<String, dynamic>? _clean(GroupMatch match, Map<String, dynamic> result) =>
      withoutBotStatistics(result, {
        if (match.homePlayer?.bot != null) 0,
        if (match.awayPlayer?.bot != null) 1,
      });
  String _canonical(dynamic value) {
    dynamic sorted(dynamic v) => v is Map
        ? {
            for (final key in (v.keys.cast<String>().toList()..sort()))
              key: sorted(v[key]),
          }
        : v is List
        ? v.map(sorted).toList()
        : v;
    return jsonEncode(sorted(value));
  }
}
