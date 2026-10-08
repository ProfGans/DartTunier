import 'dart:convert';
import 'order_of_play/order_of_play_controller.dart';
import '../domain/tournament_models.dart';

/// Opaque assignment token; changes when a match is restarted or reseeded.
class TournamentMatchAssignment {
  static String id(CreatedTournament tournament, PlayEntry entry) {
    final index = const OrderOfPlayController()
        .entries(tournament)
        .indexWhere((item) => identical(item.match, entry.match));
    return jsonEncode([
      tournament.id,
      index,
      entry.match.startedAt?.microsecondsSinceEpoch,
      entry.match.homePlayer?.toJson(),
      entry.match.awayPlayer?.toJson(),
      entry.stageIndex < tournament.stages.length
          ? tournament.stages[entry.stageIndex].gameFormat.toJson()
          : null,
    ]);
  }
}
