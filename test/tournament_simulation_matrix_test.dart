import 'package:flutter_test/flutter_test.dart';

import 'support/tournament_simulation_engine.dart';
import 'support/tournament_simulation_report_log.dart';
import 'support/tournament_simulation_scenarios.dart';

void main() {
  group('tournament simulation engine', () {
    test('completes common tournament option matrix', () {
      final engine = TournamentSimulationEngine();
      final reports = <TournamentSimulationReport>[];
      final failures = <String>[];
      for (final scenario in tournamentDevelopmentScenarios) {
        try {
          reports.add(engine.run(scenario));
        } catch (error) {
          failures.add('${scenario.name}: $error');
        }
      }
      writeTournamentSimulationLog(reports, failures: failures);

      for (var index = 0; index < reports.length; index++) {
        final report = reports[index];
        final scenario = tournamentDevelopmentScenarios.firstWhere((s) => s.name == report.scenarioName);
        final expectedFinalCount = scenario.stages.last.qualifiers;

        expect(
          report.finalPlayers,
          hasLength(expectedFinalCount),
          reason:
              '${report.scenarioName} muss $expectedFinalCount '
              'finale Weiterkommende ermitteln.',
        );
        expect(
          report.totalMatches,
          greaterThan(0),
          reason: '${report.scenarioName} muss Spiele erzeugen.',
        );
        for (final stage in report.stageReports) {
          expect(
            stage.outputCount,
            inInclusiveRange(1, stage.inputCount),
            reason: '${report.scenarioName} / ${stage.name}',
          );
        }
      }
      expect(failures, isEmpty, reason: 'Produktive Laufzeit blockiert; Details im Turnier-Simulationslog.');
    });

    test('detects impossible qualifier requests', () {
      const scenario = TournamentSimulationScenario(
        name: 'ungueltige KO-Qualifikation',
        playerCount: 4,
        stages: [
          SimulationEliminationStageSpec(
            name: 'K.-o.-Runde',
            qualifiers: 5,
            lossLimit: 1,
          ),
        ],
      );

      expect(
        () => TournamentSimulationEngine().run(scenario),
        throwsA(isA<TournamentSimulationFailure>()),
      );
    });
  });
}
