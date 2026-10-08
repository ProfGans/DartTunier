import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_tournament_manager/features/dev_tools/domain/tournament_simulation_engine.dart';
import 'package:dart_tournament_manager/features/dev_tools/domain/tournament_simulation_report.dart';
import 'package:dart_tournament_manager/features/dev_tools/presentation/simulation_visual_page.dart';
import 'package:dart_tournament_manager/features/dev_tools/presentation/simulation_graph.dart';

void main() {
  final report = TournamentSimulationEngine().run(
    const TournamentSimulationScenario(
      name: 'Swiss-Test',
      playerCount: 8,
      stages: [
        SimulationGroupStageSpec(
          name: 'Swiss',
          qualifiers: 1,
          groupSizes: [8],
          playTypes: ['swiss'],
          roundRobinRepeats: [3],
          fixedPerGroup: 1,
        ),
      ],
    ),
  );
  test('Swiss report uses numbered rounds instead of elimination rounds', () {
    expect(
      report.stageReports.single.matchRecords.every((r) => r.isRoundBased),
      true,
    );
    final text = formatTournamentSimulationLog([report]);
    for (var r = 1; r <= 3; r++) {
      expect(text, contains('Runde $r'));
    }
    expect(text, isNot(contains('Halbfinale')));
    expect(text, isNot(contains('Viertelfinale')));
    expect(text, isNot(contains('    Finale')));
  });
  for (final size in [
    const Size(360, 800),
    const Size(800, 600),
    const Size(1440, 900),
  ]) {
    testWidgets('Swiss preview has no KO tree at $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(home: SimulationVisualPage(report: report)),
      );
      expect(find.byType(SimulationGraph), findsNothing);
      await tester.scrollUntilVisible(find.text('Alle gespielten Matches'), 250, scrollable: find.descendant(of: find.byType(ListView).first, matching: find.byType(Scrollable)).first);
      await tester.tap(find.text('Alle gespielten Matches'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Runde 1'), findsWidgets);
      expect(find.textContaining('Halbfinale'), findsNothing);
      expect(find.textContaining('Viertelfinale'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
