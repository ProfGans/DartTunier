import '../../statistics/domain/saved_scorer_match.dart';
import '../../statistics/domain/bot_statistics_privacy.dart';
import '../../tournaments/application/order_of_play/order_of_play_controller.dart';
import '../../tournaments/domain/tournament_models.dart';
import 'board_display_projector.dart';

class DeviceResultImporter {
  const DeviceResultImporter();
  GroupMatch validate(
    CreatedTournament tournament,
    Map<String, dynamic> result,
  ) {
    final entry = const OrderOfPlayController()
        .entries(tournament)
        .where(
          (entry) =>
              BoardDisplayProjector.matchId(tournament, entry) ==
              result['matchId'],
        )
        .firstOrNull;
    if (entry == null ||
        entry.stageIndex != tournament.activeStageIndex ||
        result['version'] != 1) {
      throw StateError('Veraltete Spielzuweisung');
    }
    final match = entry.match;
    if (match.deviceResult?['matchId'] == result['matchId']) return match;
    if (match.isResolved || match.startedAt == null || !match.hasPlayers) {
      throw StateError('Spiel wurde bereits geändert');
    }
    final format = tournament.stages[entry.stageIndex].gameFormat;
    final legs = List<int>.from(result['legs'] as List);
    final sets = List<int>.from(result['sets'] as List);
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
    final draw = format.allowsDraws && stats.winner == null &&
        legs[0] == format.bestOfLegs ~/ 2 && legs[1] == legs[0] &&
        sets.every((n) => n == 0);
    final win = stats.winner;
    final scores = format.bestOfSets > 1 ? sets : legs;
    final target =
        (format.bestOfSets > 1 ? format.bestOfSets : format.bestOfLegs) ~/ 2 +
        1;
    if (!draw && (win == null || scores[win] != target || scores[1 - win] >= target ||
        (format.allowsDraws && legs[0] + legs[1] > format.bestOfLegs))) {
      throw const FormatException('Ergebnis passt nicht zum Spielformat');
    }
    for (var i = 0; i < 2; i++) {
      if ([match.homePlayer, match.awayPlayer][i]?.bot != null) continue;
      final calculated = SavedScorerMatch.fromJson({...stats.toJson(), 'playerIndex': i}).statistics;
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
}
