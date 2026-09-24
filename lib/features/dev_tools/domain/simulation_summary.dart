import 'tournament_simulation_engine.dart';

String simulationTypeLabel(TournamentSimulationScenario scenario) => scenario
    .stages
    .map((stage) {
      if (stage is SimulationGroupStageSpec) {
        final modes = stage.playTypes.isEmpty
            ? ['round_robin']
            : stage.playTypes;
        final labels = modes
            .map(
              (mode) => switch (mode) {
                'double_knockout' => 'Doppel-KO',
                'triple_knockout' => 'Triple-KO',
                'mini_knockout' => 'Mini-KO',
                _ => 'Jeder gegen jeden',
              },
            )
            .toSet()
            .join(' / ');
        return '${stage.groupSizes.length} Gruppen ($labels)';
      }
      final elimination = stage as SimulationEliminationStageSpec;
      if (elimination.lossLimit > 1 && !elimination.finalEndsTournament) return 'Kratzer-Modus (${elimination.lossLimit} Leben)';
      return switch (elimination.lossLimit) {
        2 => 'Doppel-KO',
        3 => 'Triple-KO',
        _ => 'Einfach-KO',
      };
    })
    .join(' → ');

int simulationDrawCount(TournamentSimulationReport report) => report
    .stageReports
    .expand((stage) => stage.matches)
    .where((match) => match.hasResult && match.winner == null)
    .length;
