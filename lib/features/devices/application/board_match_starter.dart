import '../../tournaments/application/order_of_play/order_of_play_controller.dart';
import '../../tournaments/domain/tournament_models.dart';
import 'board_display_projector.dart';

class BoardMatchStarter {
  const BoardMatchStarter();
  GroupMatch? start(
    CreatedTournament tournament,
    int stage,
    int board,
    String matchId,
  ) {
    if (!tournament.allowDeviceStart) return null;
    const order = OrderOfPlayController();
    final candidates = order
        .plan(tournament, stage)
        .planned
        .where(
          (assignment) =>
              assignment.board == board &&
              BoardDisplayProjector.matchId(tournament, assignment.entry) ==
                  matchId,
        );
    if (candidates.isEmpty) return null;
    final match = candidates.first.entry.match;
    return order.start(tournament, stage, match, board) ? match : null;
  }
}
