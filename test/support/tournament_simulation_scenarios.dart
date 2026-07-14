import 'tournament_simulation_engine.dart';

const tournamentDevelopmentScenarios = [
  TournamentSimulationScenario(
    name: 'nur KO mit 7 Spielern',
    playerCount: 7,
    stages: [
      SimulationEliminationStageSpec(
        name: 'K.-o.-Runde',
        qualifiers: 1,
        lossLimit: 1,
      ),
    ],
  ),
  TournamentSimulationScenario(
    name: 'nur KO mit 3 von 5 Weiterkommenden',
    playerCount: 5,
    stages: [
      SimulationEliminationStageSpec(
        name: 'Mini-K.-o.-Qualifikation',
        qualifiers: 3,
        lossLimit: 1,
      ),
    ],
  ),
  TournamentSimulationScenario(
    name: 'KO in KO mit 13 Spielern',
    playerCount: 13,
    stages: [
      SimulationEliminationStageSpec(
        name: 'Play-in-K.-o.',
        qualifiers: 8,
        lossLimit: 1,
      ),
      SimulationEliminationStageSpec(
        name: 'Final-K.-o.',
        qualifiers: 1,
        lossLimit: 1,
      ),
    ],
  ),
  TournamentSimulationScenario(
    name: 'nur Doppel-KO mit 10 Spielern',
    playerCount: 10,
    stages: [
      SimulationEliminationStageSpec(
        name: 'Doppel-K.-o.',
        qualifiers: 1,
        lossLimit: 2,
      ),
    ],
  ),
  TournamentSimulationScenario(
    name: 'Doppel-KO mit 5 von 9 Weiterkommenden',
    playerCount: 9,
    stages: [
      SimulationEliminationStageSpec(
        name: 'Doppel-K.-o.-Qualifikation',
        qualifiers: 5,
        lossLimit: 2,
      ),
    ],
  ),
  TournamentSimulationScenario(
    name: 'Doppel-KO in KO mit 18 Spielern',
    playerCount: 18,
    stages: [
      SimulationEliminationStageSpec(
        name: 'Doppel-K.-o.-Vorrunde',
        qualifiers: 6,
        lossLimit: 2,
      ),
      SimulationEliminationStageSpec(
        name: 'K.-o.-Endrunde',
        qualifiers: 1,
        lossLimit: 1,
      ),
    ],
  ),
  TournamentSimulationScenario(
    name: 'nur Triple-KO mit 12 Spielern',
    playerCount: 12,
    stages: [
      SimulationEliminationStageSpec(
        name: 'Triple-K.-o.',
        qualifiers: 1,
        lossLimit: 3,
      ),
    ],
  ),
  TournamentSimulationScenario(
    name: 'Triple-KO mit 4 von 11 Weiterkommenden',
    playerCount: 11,
    stages: [
      SimulationEliminationStageSpec(
        name: 'Triple-K.-o.-Qualifikation',
        qualifiers: 4,
        lossLimit: 3,
      ),
    ],
  ),
  TournamentSimulationScenario(
    name: 'Liga-Gruppen in KO',
    playerCount: 24,
    stages: [
      SimulationGroupStageSpec(
        name: 'Gruppenphase',
        groupSizes: [4, 4, 4, 4, 4, 4],
        qualifiers: 16,
        fixedPerGroup: 2,
        extraRank: 3,
        extraCount: 4,
        extraGroups: [1, 2, 3, 4, 5, 6],
        roundRobinRepeats: [1, 1, 2, 1, 1, 2],
      ),
      SimulationEliminationStageSpec(
        name: 'Finalrunde',
        qualifiers: 1,
        lossLimit: 1,
      ),
    ],
  ),
  TournamentSimulationScenario(
    name: 'ungleiche Liga-Gruppen mit manueller Verteilung',
    playerCount: 17,
    stages: [
      SimulationGroupStageSpec(
        name: 'Gruppenphase',
        groupSizes: [5, 4, 4, 4],
        qualifiers: 9,
        fixedPerGroup: 0,
        fixedByGroup: [3, 2, 2, 1],
        extraRank: 2,
        extraCount: 1,
        extraGroups: [4],
        roundRobinRepeats: [2, 1, 1, 2],
      ),
      SimulationEliminationStageSpec(
        name: 'Doppel-K.-o.-Zwischenrunde',
        qualifiers: 4,
        lossLimit: 2,
      ),
      SimulationEliminationStageSpec(
        name: 'Final-K.-o.',
        qualifiers: 1,
        lossLimit: 1,
      ),
    ],
  ),
  TournamentSimulationScenario(
    name: 'gemischte Gruppen in Doppel-KO',
    playerCount: 27,
    stages: [
      SimulationGroupStageSpec(
        name: 'Gemischte Gruppenphase',
        groupSizes: [4, 4, 4, 4, 4, 4, 3],
        playTypes: [
          'round_robin',
          'mini_knockout',
          'double_knockout',
          'triple_knockout',
          'round_robin',
          'mini_knockout',
          'round_robin',
        ],
        qualifiers: 14,
        fixedPerGroup: 1,
        extraRank: 2,
        extraCount: 7,
        extraGroups: [1, 2, 3, 4, 5, 6, 7],
      ),
      SimulationEliminationStageSpec(
        name: 'Doppel-K.-o.-Finalrunde',
        qualifiers: 1,
        lossLimit: 2,
      ),
    ],
  ),
  TournamentSimulationScenario(
    name: 'kleine gemischte Gruppen mit knapper Qualifikation',
    playerCount: 14,
    stages: [
      SimulationGroupStageSpec(
        name: 'Gemischte Kurzphase',
        groupSizes: [3, 3, 4, 4],
        playTypes: [
          'mini_knockout',
          'round_robin',
          'double_knockout',
          'triple_knockout',
        ],
        qualifiers: 7,
        fixedByGroup: [1, 1, 2, 2],
        extraRank: 2,
        extraCount: 1,
        extraGroups: [1, 2],
      ),
      SimulationEliminationStageSpec(
        name: 'K.-o.-Finalrunde',
        qualifiers: 1,
        lossLimit: 1,
      ),
    ],
  ),
  TournamentSimulationScenario(
    name: 'Gruppenphase in Gruppenphase in Triple-KO',
    playerCount: 32,
    stages: [
      SimulationGroupStageSpec(
        name: 'Vorrunde',
        groupSizes: [4, 4, 4, 4, 4, 4, 4, 4],
        qualifiers: 24,
        fixedPerGroup: 3,
      ),
      SimulationGroupStageSpec(
        name: 'Zwischenrunde',
        groupSizes: [6, 6, 6, 6],
        playTypes: [
          'round_robin',
          'mini_knockout',
          'double_knockout',
          'triple_knockout',
        ],
        qualifiers: 12,
        fixedPerGroup: 2,
        extraRank: 3,
        extraCount: 4,
        extraGroups: [1, 2, 3, 4],
      ),
      SimulationEliminationStageSpec(
        name: 'Triple-K.-o.-Finalrunde',
        qualifiers: 1,
        lossLimit: 3,
      ),
    ],
  ),
  TournamentSimulationScenario(
    name: 'drei Etappen mit wechselnden Modi und ungeraden Feldern',
    playerCount: 21,
    stages: [
      SimulationGroupStageSpec(
        name: 'Vorrunde',
        groupSizes: [4, 4, 4, 3, 3, 3],
        playTypes: [
          'round_robin',
          'mini_knockout',
          'round_robin',
          'double_knockout',
          'mini_knockout',
          'triple_knockout',
        ],
        qualifiers: 13,
        fixedPerGroup: 2,
        extraRank: 3,
        extraCount: 1,
        extraGroups: [1, 2, 3],
      ),
      SimulationEliminationStageSpec(
        name: 'Triple-K.-o.-Zwischenrunde',
        qualifiers: 5,
        lossLimit: 3,
      ),
      SimulationGroupStageSpec(
        name: 'Finalgruppe',
        groupSizes: [5],
        qualifiers: 2,
        fixedPerGroup: 2,
        roundRobinRepeats: [2],
      ),
      SimulationEliminationStageSpec(
        name: 'Finale',
        qualifiers: 1,
        lossLimit: 1,
      ),
    ],
  ),
];
