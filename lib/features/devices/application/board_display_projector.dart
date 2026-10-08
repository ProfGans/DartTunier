import 'dart:convert';
import '../../tournaments/application/order_of_play/order_of_play_controller.dart';
import '../../tournaments/domain/tournament_models.dart';
import '../domain/board_display.dart';

class BoardDisplayProjector {
  const BoardDisplayProjector();
  Map<int, BoardDisplay> project(
    CreatedTournament tournament,
    int activeStage,
  ) {
    final complete =
        tournament.runStages.isNotEmpty &&
        tournament.completedStageIndexes.contains(
          tournament.runStages.length - 1,
        );
    final schedule = const OrderOfPlayController().plan(
      tournament,
      activeStage,
    );
    return {
      for (var board = 1; board <= tournament.boardCount; board++)
        board: _board(tournament, schedule, board, complete),
    };
  }

  BoardDisplay _board(
    CreatedTournament tournament,
    BoardSchedule schedule,
    int board,
    bool complete,
  ) {
    PlayEntry? entry;
    var state = complete ? 'finished' : 'waiting';
    var detail = '';
    if (!complete) {
      final running = schedule.running.where(
        (e) => e.match.boardNumber == board,
      );
      final planned = schedule.planned.where((a) => a.board == board);
      if (running.isNotEmpty) {
        entry = running.first;
        state = 'running';
      } else if (planned.isNotEmpty) {
        entry = planned.first.entry;
        state = 'planned';
        detail = 'Block ${planned.first.block + 1} · ';
      }
    }
    return BoardDisplay(
      allowDeviceStart: tournament.allowDeviceStart && state == 'planned',
      tournamentId: tournament.id,
      tournamentName: tournament.name,
      board: board,
      state: state,
      home: entry?.match.homePlayer?.name ?? '',
      homeBot: entry?.match.homePlayer?.bot,
      awayBot: entry?.match.awayPlayer?.bot,
      away: entry?.match.awayPlayer?.name ?? '',
      homeMembers: entry?.match.homePlayer?.members.map((p) => p.name).toList() ?? const [],
      awayMembers: entry?.match.awayPlayer?.members.map((p) => p.name).toList() ?? const [],
      detail: '$detail${entry?.origin ?? ''}',
      format: entry != null && entry.stageIndex < tournament.stages.length
          ? tournament.stages[entry.stageIndex].gameFormat.label
          : '',
      score: entry?.match.scoreLabel ?? '',
      matchId: entry == null ? null : matchId(tournament, entry),
      gameFormat: entry != null && entry.stageIndex < tournament.stages.length
          ? tournament.stages[entry.stageIndex].gameFormat
          : null,
    );
  }

  static String matchId(CreatedTournament tournament, PlayEntry entry) {
    final index = const OrderOfPlayController()
        .entries(tournament)
        .indexWhere((item) => identical(item.match, entry.match));
    return jsonEncode([tournament.id, index, entry.match.startedAt?.microsecondsSinceEpoch,
      entry.match.homePlayer?.toJson(), entry.match.awayPlayer?.toJson(),
      entry.stageIndex < tournament.stages.length ? tournament.stages[entry.stageIndex].gameFormat.toJson() : null]);
  }
}
