import '../../domain/knockout_round_names.dart';
import '../../domain/tournament_models.dart';
import '../../domain/engines/board_scheduling_engine.dart';
export '../../domain/engines/board_scheduling_engine.dart';

/// Deterministic greedy scheduling: fill boards, then prefer rested players.
/// No predictions of winners: unresolved future pairings stay in the waiting list.
class OrderOfPlayController {
  const OrderOfPlayController();

  List<PlayEntry> entries(CreatedTournament tournament) {
    final result = <PlayEntry>[];
    for (var index = 0; index < tournament.runStages.length; index++) {
      final stage = tournament.runStages[index];
      if (stage is GroupTournamentRunStage) {
        for (final group in stage.groups) {
          final matches = group.knockoutRounds.isEmpty
              ? group.matches
              : <GroupMatch>[
                  for (final round in group.knockoutRounds) ...round,
                  ...group.placementMatches,
                  ...group.matches.where((match) => match.isDecider),
                ];
          for (final match in matches) {
            result.add(
              PlayEntry(match, index, '${stage.name} · ${group.name} · ${stageMatchName(stage, match)}'),
            );
          }
        }
      } else if (stage is KnockoutTournamentRunStage) {
        for (final match in stage.matches) {
          result.add(
            PlayEntry(match, index, '${stage.name} · ${stageMatchName(stage, match)}'),
          );
        }
      }
    }
    return result;
  }

  BoardSchedule plan(CreatedTournament tournament, int activeStage) {
    if (tournament.boardCount < 1 || tournament.boardCount > 64) {
      throw ArgumentError.value(tournament.boardCount, 'boardCount');
    }
    final all = entries(tournament);
    final finished =
        all
            .where((e) => e.stageIndex <= activeStage && e.match.isResolved)
            .toList()
          ..sort(
            (a, b) => (a.match.finishedAt ?? DateTime(1970)).compareTo(
              b.match.finishedAt ?? DateTime(1970),
            ),
          );
    final running =
        all
            .where(
              (e) =>
                  e.stageIndex == activeStage &&
                  !e.match.isResolved &&
                  e.match.hasPlayers &&
                  e.match.startedAt != null &&
                  e.match.finishedAt == null &&
                  e.match.startedPlayers == e.playerSignature &&
                  e.match.boardNumber != null,
            )
            .toList()
          ..sort((a, b) => a.match.startedAt!.compareTo(b.match.startedAt!));
    final pending = all
        .where(
          (e) =>
              e.stageIndex == activeStage &&
              e.match.hasPlayers &&
              !e.match.isResolved &&
              !running.contains(e),
        )
        .toList();
    final waiting = all
        .where(
          (e) =>
              !finished.contains(e) &&
              !pending.contains(e) &&
              !running.contains(e),
        )
        .toList();
    final planned = const BoardSchedulingEngine().schedule(
      all: all,
      ready: pending,
      running: running,
      finished: finished,
      boardCount: tournament.boardCount,
    );
    return BoardSchedule(planned, running, finished, waiting);
  }

  bool start(
    CreatedTournament tournament,
    int stage,
    GroupMatch match,
    int board,
  ) {
    final schedule = plan(tournament, stage);
    final candidates = schedule.planned.where(
      (a) => identical(a.entry.match, match),
    );
    if (candidates.isEmpty || board < 1 || board > tournament.boardCount) {
      return false;
    }
    final entry = candidates.first.entry;
    if (schedule.running.any(
      (e) =>
          e.match.boardNumber == board || e.players.any(entry.players.contains),
    )) {
      return false;
    }
    match.boardNumber = board;
    match.startedAt = DateTime.now();
    match.startedPlayers = entry.playerSignature;
    match.finishedAt = null;
    return true;
  }

  void resultRecorded(GroupMatch match) {
    if (match.isResolved) {
      match.finishedAt ??= DateTime.now();
    } else {
      match.finishedAt = null;
      match.startedAt = null;
      match.boardNumber = null;
      match.startedPlayers = null;
    }
  }
}
