import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:dart_tournament_manager/features/dev_tools/domain/random_tournament_simulations.dart';
import 'package:dart_tournament_manager/features/dev_tools/domain/tournament_simulation_engine.dart';
import 'package:dart_tournament_manager/features/dev_tools/presentation/simulation_graph.dart';
void main() {
  test('seed 106 triple KO eliminates players only at three losses', () {
    final result = runRandomSimulations(const RandomSimulationRequest(seed: 106, count: 1)).single;
    expect(result['passed'], true);
    final report = result['report'] as TournamentSimulationReport;
    final stage = report.stageReports.last;
    expect(stage.inputCount, 4);
    expect(stage.matchCount, 9);
    final layout = SimulationGraphLayout(stage.matchRecords);
    final winners = stage.matchRecords.where((r) => r.match.label!.startsWith('0 Niederlagen')).toList();
    final losers = stage.matchRecords.where((r) => r.match.label!.startsWith('1 Niederlage')).toList();
    final secondLosers = stage.matchRecords.where((r) => r.match.label!.startsWith('2 Niederlagen')).toList();
    expect(layout.positions[losers.first.number]!.dy,
        greaterThan(winners.map((r) => layout.positions[r.number]!.dy + 130).reduce((a, b) => a > b ? a : b)));
    expect(layout.positions[secondLosers.first.number]!.dy,
        greaterThan(losers.map((r) => layout.positions[r.number]!.dy + 130).reduce((a, b) => a > b ? a : b)));
    for (final edge in layout.edges) {
      for (final metric in edge.path.computeMetrics()) {
        for (var distance = 1.0; distance < metric.length; distance += 2) {
          final point = metric.getTangentForOffset(distance)!.position;
          for (final position in layout.positions.values) {
            expect((position & const Size(260, 130)).deflate(1).contains(point), isFalse);
          }
        }
      }
    }
    final losses = <String, int>{};
    for (final record in stage.matchRecords) {
      for (final player in [record.match.homePlayer, record.match.awayPlayer]) {
        if (player == null) continue;
        expect(losses[player.name] ?? 0, lessThan(3));
        expect(layout.lossesBefore['${record.number}:${player.name}'], losses[player.name] ?? 0);
      }
      final loser = record.match.loser;
      if (loser != null && record.match.hasResult) losses[loser.name] = (losses[loser.name] ?? 0) + 1;
    }
    expect(losses.values.where((count) => count == 3), hasLength(3));
    expect(losses[report.finalPlayers.single.name] ?? 0, 0);
    expect(stage.matchRecords.first.match.label, '0 Niederlagen Runde 1');
    expect(stage.matchRecords.first.match.hasSetScore, true);
  });
}
