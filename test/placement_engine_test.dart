import 'package:flutter_test/flutter_test.dart';
import 'package:dart_tournament_manager/features/dev_tools/domain/tournament_simulation_engine.dart';

void main() {
  test('optional places build only required classification branches', () {
    for (final selection in [<int>[], [3], [5], [7], [3, 5, 7], [9, 11, 13, 15]]) {
      final report = TournamentSimulationEngine().run(TournamentSimulationScenario(
        name: 'Platzierung', playerCount: 16,
        stages: [SimulationEliminationStageSpec(name: 'KO', qualifiers: 16, lossLimit: 1, placementPlaces: selection)],
      ));
      final matches = report.stageReports.single.matchRecords.map((r) => r.match).toList();
      expect(matches.map((m) => m.placementRank).whereType<int>().toSet(), selection.toSet());
      for (final match in matches.where((m) => m.placementRank != null)) {
        expect(report.finalPlayers[match.placementRank! - 1].name, match.winner!.name);
        expect(report.finalPlayers[match.placementRank!].name, match.loser!.name);
      }
    }
  });
  test('placements finish with byes and random results', () {
    for (final count in [5, 6, 9, 11, 13, 17]) {
      for (var seed = 0; seed < 5; seed++) {
        final report = TournamentSimulationEngine().run(TournamentSimulationScenario(
          name: 'Freilose', playerCount: count,
          stages: [SimulationEliminationStageSpec(name: 'KO', qualifiers: 1, lossLimit: 1,
            placementPlaces: [for (var rank = 3; rank < count; rank += 2) rank])],
        ), seed: seed, randomResults: true);
        expect(report.finalPlayers, hasLength(1));
      }
    }
  });
  test('mini KO groups play selected places before qualification', () {
    final report = TournamentSimulationEngine().run(const TournamentSimulationScenario(
      name: 'Mini-KO', playerCount: 16, stages: [
        SimulationGroupStageSpec(name: 'Gruppen', qualifiers: 4, groupSizes: [8, 8],
          playTypes: ['mini_knockout', 'mini_knockout'], fixedPerGroup: 2, placementPlaces: [3, 5, 7]),
        SimulationEliminationStageSpec(name: 'Finale', qualifiers: 1, lossLimit: 1),
      ],
    ));
    final placements = report.stageReports.first.matchRecords.where((r) => r.match.placementRank != null);
    expect(placements, hasLength(6));
  });
}
