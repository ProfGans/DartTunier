import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_tournament_manager/features/dev_tools/domain/tournament_simulation_engine.dart';
import 'package:dart_tournament_manager/features/dev_tools/presentation/simulation_visual_page.dart';

void main() {
  testWidgets('Triple KO graph renders the production matches and finals', (tester) async {
    final report = TournamentSimulationEngine().run(
      const TournamentSimulationScenario(name: 'Triple KO', playerCount: 12,
        stages: [SimulationEliminationStageSpec(name: 'Triple KO', qualifiers: 1, lossLimit: 3)]),
    );
    expect(report.stageReports.single.matches.where((m) => m.label == 'Triple-KO Finalrunde').length, greaterThanOrEqualTo(2));
    await tester.pumpWidget(MaterialApp(home: SimulationVisualPage(report: report)));
    await tester.pumpAndSettle();
    expect(find.byType(InteractiveViewer), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('simulation shows group statistics and graphical knockout rounds', (tester) async {
    final report=TournamentSimulationEngine().run(const TournamentSimulationScenario(name:'Visual Test',playerCount:8,stages:[
      SimulationGroupStageSpec(name:'Gruppen',qualifiers:4,groupSizes:[4,4],fixedPerGroup:2),
      SimulationEliminationStageSpec(name:'Finalrunde',qualifiers:1,lossLimit:1),
    ]));
    expect(report.stageReports.first.groupTables.length,2);
    for(final table in report.stageReports.first.groupTables.values) {
      expect(table.length,4);
      expect(table.every((row)=>row.played==3),isTrue);
      expect(table.fold<int>(0,(sum,row)=>sum+row.points),18);
    }
    await tester.pumpWidget(MaterialApp(home:SimulationVisualPage(report:report)));
    await tester.pumpAndSettle();
    expect(find.byType(DataTable),findsWidgets);
    expect(tester.takeException(),isNull);
    await tester.tap(find.text('Finalrunde'));
    await tester.pumpAndSettle();
    expect(find.byType(InteractiveViewer),findsOneWidget);
    expect(find.text('Turnierbaum'),findsOneWidget);
    expect(tester.takeException(),isNull);
  });
}
