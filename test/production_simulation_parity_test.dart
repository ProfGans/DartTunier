import 'package:flutter_test/flutter_test.dart';
import 'package:dart_tournament_manager/features/dev_tools/domain/tournament_simulation_engine.dart';
import 'package:dart_tournament_manager/features/tournaments/domain/engines/group_bye_seeding.dart';
import 'package:dart_tournament_manager/features/tournaments/domain/tournament_models.dart';

void main() {
  test('production knockout bracket contains its actual first-round bye', () {
    final report=TournamentSimulationEngine().run(const TournamentSimulationScenario(name:'7 KO',playerCount:7,
      stages:[SimulationEliminationStageSpec(name:'KO',qualifiers:1,lossLimit:1)]));
    final stage=report.stageReports.single;
    expect(stage.matchRecords.where((r)=>r.match.round==1 && !r.match.hasPlayers).length,1);
    expect(stage.matches.where((m)=>m.round==1).length,3);
    expect(stage.matches.where((m)=>m.label==null).length,6);
  });
  test('group comparison determines the two actual byes in the test bracket', () {
    for(final seed in [7,42]) {
      final report=TournamentSimulationEngine().run(const TournamentSimulationScenario(name:'13 groups KO',playerCount:13,
        stages:[SimulationGroupStageSpec(name:'Groups',qualifiers:6,groupSizes:[5,4,4],fixedPerGroup:2),
          SimulationEliminationStageSpec(name:'KO',qualifiers:1,lossLimit:1)]),seed:seed);
      final winners=<BestOfCandidate>[];
      var number=0;
      for(final table in report.stageReports.first.groupTables.entries) {
        winners.add(BestOfCandidate(groupName:table.key,groupNumber:++number,place:1,standing:table.value.first));
      }
      winners.sort((a,b)=>const GroupByeSeeding().compare(a,b,defaultGroupTieBreakers));
      final byes=report.stageReports.last.matchRecords.where((r)=>r.match.round==1 && !r.match.hasPlayers).toList();
      expect(byes.length,2);
      expect(byes.map((r)=>r.match.winner!.name).toSet(),winners.take(2).map((r)=>r.standing.player.name).toSet());
    }
  });
}
