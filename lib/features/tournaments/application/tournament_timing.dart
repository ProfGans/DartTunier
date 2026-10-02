import 'dart:math';
import '../domain/tournament_models.dart';
import '../domain/tournament_planning_parameters.dart';
import '../domain/tournament_format_planner.dart';
import 'configuration_duration_estimator.dart';
import 'order_of_play/order_of_play_controller.dart';
import '../../league/application/league_board_runtime.dart';
import '../../settings/data/planning_settings_storage.dart';

class TournamentTiming {
  static Future<void> prepare(CreatedTournament tournament) async {
    if (tournament.startedAt == null &&
        !matches(tournament).any((m) => m.startedAt != null)) {
      return;
    }
    var parameters = const TournamentPlanningParameters();
    if (tournament.plannedMinutes == null) {
      try {
        parameters = await PlanningSettingsStorage().load();
      } catch (_) {
        /* Timing must not prevent saving a match result. */
      }
    }
    capture(tournament, parameters);
  }

  static List<GroupMatch> matches(CreatedTournament tournament) =>
      tournament.leagueMatch != null
      ? LeagueBoardRuntime(tournament).matches
      : const OrderOfPlayController()
            .entries(tournament)
            .map((e) => e.match)
            .toList();

  /// Called by the application before saving. A saved baseline never moves.
  static void capture(
    CreatedTournament tournament,
    TournamentPlanningParameters parameters,
  ) {
    final games = matches(tournament);
    final starts = games.map((m) => m.startedAt).whereType<DateTime>().toList()
      ..sort();
    if (tournament.startedAt == null && starts.isNotEmpty) {
      tournament.startedAt = starts.first;
    }
    if (tournament.startedAt == null) return;
    if (tournament.plannedMinutes == null) {
      try {
        if (tournament.leagueMatch != null) {
          final copy = CreatedTournament.fromJson(tournament.toJson());
          for (final g in copy.leagueMatch!.games) {
            g.score(null, null);
            g.runtime = null;
          }
          final schedule = LeagueBoardRuntime(copy).schedule;
          final slots = schedule.planned.isEmpty
              ? 0
              : schedule.planned.last.block + 1;
          tournament.plannedMinutes =
              (slots *
                      TournamentFormatPlanner(
                        parameters: parameters,
                      ).estimatedMatchMinutes(
                        const TournamentGameFormat(bestOfLegs: 5),
                      ))
                  .ceil();
          tournament.plannedMatches = games.where((m) => m.hasPlayers).length;
          final matchMinutes = TournamentFormatPlanner(
            parameters: parameters,
          ).estimatedMatchMinutes(const TournamentGameFormat(bestOfLegs: 5));
          tournament.plannedMatchEndSeconds = [
            for (final entry in schedule.planned)
              ((entry.block + 1) * matchMinutes * 60).round(),
          ]..sort();
        } else {
          final estimate = const ConfigurationDurationEstimator().preview(
            tournament.stages,
            tournament.boardCount,
            parameters,
          );
          tournament.plannedMinutes = estimate?.minutes;
          tournament.plannedMatches = estimate?.totalMatches;
          tournament.plannedMatchEndSeconds = estimate?.matchEndSeconds ?? [];
        }
      } catch (_) {
        /* Incomplete legacy configurations have no planning baseline. */
      }
    }
    final complete =
        tournament.leagueMatch?.complete ??
        (tournament.stages.isNotEmpty &&
            tournament.runStages.length == tournament.stages.length &&
            games.isNotEmpty &&
            games.every((m) => m.isResolved));
    if (!complete) {
      tournament.finishedAt = null;
      return;
    }
    final ends = games.map((m) => m.finishedAt).whereType<DateTime>().toList()
      ..sort();
    tournament.finishedAt ??= ends.isEmpty ? DateTime.now() : ends.last;
  }

  static TimingSnapshot snapshot(CreatedTournament tournament, DateTime now) {
    final games = matches(
      tournament,
    ).where((m) => m.hasPlayers && !m.isAnnulled).toList();
    final measured = games
        .where(
          (m) =>
              m.hasResult &&
              m.startedAt != null &&
              m.finishedAt != null &&
              !m.finishedAt!.isBefore(m.startedAt!),
        )
        .toList();
    final durations =
        measured
            .map((m) => m.finishedAt!.difference(m.startedAt!).inSeconds)
            .toList()
          ..sort();
    final elapsed = tournament.startedAt == null
        ? Duration.zero
        : (tournament.finishedAt ?? now).difference(tournament.startedAt!);
    final completed = games.where((m) => m.hasResult).length;
    DateTime? forecast = tournament.finishedAt;
    int? expectedCompleted;
    final planned = tournament.plannedMinutes;
    final total = tournament.plannedMatches;
    if (planned != null &&
        total != null &&
        total > 0 &&
        tournament.startedAt != null) {
      final seconds = max(0, elapsed.inSeconds);
      expectedCompleted = tournament.plannedMatchEndSeconds.isNotEmpty
          ? tournament.plannedMatchEndSeconds
                .where((end) => end <= seconds)
                .length
          : planned > 0
          ? (seconds * total / (planned * 60)).floor().clamp(0, total)
          : total;
      // Progress-based forecast; it is deliberately labelled as an estimate.
      // Running games contribute fractional progress using observed match length.
      final average = durations.isEmpty
          ? null
          : durations.reduce((a, b) => a + b) / durations.length;
      var progress = completed.toDouble();
      if (average != null && average > 0) {
        for (final game in games.where(
          (m) => !m.isResolved && m.startedAt != null,
        )) {
          progress += (now.difference(game.startedAt!).inSeconds / average)
              .clamp(0, 1);
        }
      }
      final remainingFraction = (1 - progress / max(total, completed)).clamp(
        0.0,
        1.0,
      );
      final secondsPerFraction = progress > 0
          ? max(0, elapsed.inSeconds) / (progress / max(total, completed))
          : planned * 60.0;
      forecast = completed == 0
          ? null
          : tournament.finishedAt ??
                now.add(
                  Duration(
                    seconds: (remainingFraction * secondsPerFraction).round(),
                  ),
                );
    }
    return TimingSnapshot(
      elapsed.isNegative ? Duration.zero : elapsed,
      durations,
      completed,
      games.where((m) => m.hasResult).length - durations.length,
      forecast,
      expectedCompleted,
    );
  }
}

class TimingSnapshot {
  const TimingSnapshot(
    this.elapsed,
    this.matchSeconds,
    this.completed,
    this.unmeasured,
    this.forecast,
    this.expectedCompleted,
  );
  final Duration elapsed;
  final List<int> matchSeconds;
  final int completed, unmeasured;
  final int? expectedCompleted;
  final DateTime? forecast;
  double? get averageSeconds => matchSeconds.isEmpty
      ? null
      : matchSeconds.reduce((a, b) => a + b) / matchSeconds.length;
}
