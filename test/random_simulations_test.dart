import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart';
import 'package:dart_tournament_manager/features/dev_tools/domain/random_tournament_simulations.dart';
import 'package:dart_tournament_manager/features/dev_tools/domain/tournament_simulation_engine.dart';
import 'package:dart_tournament_manager/features/tournaments/domain/tournament_format_planner.dart';

void main() {
  test(
    'random groups simulate draws and summaries expose tournament types',
    () {
      final results = runRandomSimulations(
        const RandomSimulationRequest(seed: 1000, count: 100),
      );
      expect(results.every((r) => (r['type'] as String).isNotEmpty), isTrue);
      expect(results.any((r) => r['allowsDraws'] == true), isTrue);
      expect(results.any((r) => (r['draws'] as int? ?? 0) > 0), isTrue);
      for (final result in results.where((r) => r['passed'] == true)) {
        final report = result['report']! as TournamentSimulationReport;
        for (final stage in report.stageReports) {
          for (final record in stage.matchRecords.where(
            (r) => r.match.hasResult && r.match.winner == null,
          )) {
            expect(record.bracket.endsWith(' - Liga'), isTrue);
            expect(record.match.isDecider, isFalse);
          }
        }
      }
    },
  );
  test(
    'random runner returns graphical reports from the app isolate',
    () async {
      final results = await compute(
        runRandomSimulations,
        const RandomSimulationRequest(seed: 120, count: 1),
      );
      expect(results.single['passed'], isTrue);
      expect(results.single['report'], isA<TournamentSimulationReport>());
    },
  );
  test('100 generated tournaments complete through the production runtime', () {
    final results = runRandomSimulations(
      const RandomSimulationRequest(seed: 1000, count: 100),
    );
    expect(
      results
          .where((r) => r['passed'] == false)
          .map((r) => r['detail'])
          .toList(),
      isEmpty,
    );
  });
  test('random batches reproduce layouts and match outcomes by seed', () {
    const request = RandomSimulationRequest(seed: 120, count: 12);
    final first = runRandomSimulations(request);
    final again = runRandomSimulations(request);
    expect(
      first.map((r) => r['detail']).toList(),
      again.map((r) => r['detail']).toList(),
    );
    expect(
      first.map((r) => r['seed']).toList(),
      List.generate(12, (i) => 120 + i),
    );
    final single = runRandomSimulations(
      const RandomSimulationRequest(seed: 125, count: 1),
    );
    expect(single.single['detail'], first[5]['detail']);
    expect(first.any((r) => r['passed'] == true), isTrue);
    final sizes = [
      for (var seed = 0; seed < 30; seed++)
        randomTournamentScenario(seed).playerCount,
    ];
    expect(sizes.toSet().length, greaterThan(10));
  });

  test(
    'random results include different winners without changing the layout',
    () {
      const scenario = TournamentSimulationScenario(
        name: 'KO',
        playerCount: 8,
        stages: [
          SimulationEliminationStageSpec(
            name: 'Finale',
            qualifiers: 1,
            lossLimit: 1,
          ),
        ],
      );
      final winners = {
        for (var seed = 0; seed < 15; seed++)
          TournamentSimulationEngine()
              .run(scenario, seed: seed, randomResults: true)
              .finalPlayers
              .single
              .name,
      };
      expect(winners.length, greaterThan(1));
    },
  );

  test('sets are excluded by default in every suggested stage', () {
    const request = TournamentPlanningRequest(
      players: 13,
      boards: 4,
      minimumMatchesPerPlayer: 3,
      minimumMinutes: 120,
      maximumMinutes: 360,
      x01Selection: 'variable_301_501',
      checkoutType: 'double_out',
    );
    expect(request.allowSets, isFalse);
    final suggestions = const TournamentFormatPlanner().suggestFormats(request);
    expect(suggestions, isNotEmpty);
    expect(
      suggestions
          .expand((s) => s.stages)
          .every((s) => s.format.bestOfSets == 1),
      isTrue,
    );
  });
}
