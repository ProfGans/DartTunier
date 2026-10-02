import 'package:flutter_test/flutter_test.dart';
import 'package:dart_tournament_manager/features/communities/domain/community.dart';
import 'package:dart_tournament_manager/features/communities/domain/community_elo.dart';
import 'package:dart_tournament_manager/features/scorer/application/scorer_controller.dart';
import 'package:dart_tournament_manager/features/scorer/domain/scorer_settings.dart';
import 'package:dart_tournament_manager/features/devices/application/device_scorer_settings.dart';
import 'package:dart_tournament_manager/features/devices/application/device_result_importer.dart';
import 'package:dart_tournament_manager/features/devices/application/board_display_projector.dart';
import 'package:dart_tournament_manager/features/statistics/domain/saved_scorer_match.dart';
import 'package:dart_tournament_manager/features/statistics/domain/tournament_player_statistics.dart';
import 'package:dart_tournament_manager/features/tournaments/domain/tournament_models.dart';
import 'package:dart_tournament_manager/features/tournaments/application/order_of_play/order_of_play_controller.dart';

void main() {
  for (final length in [2,4,6]) {
    test('$length legs draw completes, blocks throws, supports undo and imports statistics', () {
      const a=TournamentPlayer(name:'Anna',isGenerated:false);
      const b=TournamentPlayer(name:'Ben',isGenerated:false);
      final format=TournamentGameFormat(x01Score:40,bestOfLegs:length);
      final match=GroupMatch(homePlayer:a,awayPlayer:b,round:1);
      final tournament=CreatedTournament(name:'Cup',players:[a,b],stages:[TournamentStage(name:'Gruppe',type:'groups',gameFormat:format)],
        runStages:[GroupTournamentRunStage(name:'Gruppe',groupPlayType:'round_robin',qualificationPlan:null,tieBreakers:[],groups:[TournamentGroup(name:'A',playType:'round_robin',players:[a,b],matches:[match])])]);
      const OrderOfPlayController().start(tournament,0,match,1);
      final display=const BoardDisplayProjector().project(tournament,0)[1]!;
      final controller=ScorerController(deviceScorerSettings(display));
      addTearDown(controller.dispose);
      for(var i=0;i<length;i++) { controller.submitScore(40,checkoutDarts:1,checkoutAttempts:1); }
      expect(controller.isDraw,isTrue); expect(controller.isComplete,isTrue); expect(controller.winner,isNull);
      controller.submitScore(40,checkoutDarts:1,checkoutAttempts:1);
      expect(controller.statisticsVisits,hasLength(length));
      controller.undo(); expect(controller.isComplete,isFalse);
      controller.submitScore(40,checkoutDarts:1,checkoutAttempts:1);
      final statistics=SavedScorerMatch(id:display.matchId!,accountId:'',playedAt:DateTime.now(),playerIndex:0,
        names:['Anna','Ben'],startScores:[40,40],standard501Rules:true,doubleOut:true,visits:controller.statisticsVisits,isDraw:true);
      final result=<String,dynamic>{'version':1,'matchId':display.matchId,'legs':controller.legs,'sets':controller.sets,'statistics':statistics.toJson()};
      const importer=DeviceResultImporter();
      expect(importer.validate(tournament,result),same(match)); importer.apply(match,result,format);
      expect(match.isResolved,isTrue); expect(match.winner,isNull);
      final restored=CreatedTournament.fromJson(tournament.toJson());
      final rows=const TournamentStatisticsCalculator().calculate([restored]);
      expect(rows.every((r)=>r.draws==1 && r.wins==0 && r.losses==0),isTrue);
      expect(SavedScorerMatch.fromJson(statistics.toJson()).isDraw,isTrue);
      final ranking=const CommunityEloCalculator().calculate(members:[
        for(final name in ['Anna','Ben']) CommunityMember(userId:name,displayName:name,role:'member',joinedAt:DateTime.now()),
      ],tournaments:[restored],currentYearOnly:false);
      expect(ranking.entries.every((e)=>e.draws==1 && e.matches==1 && e.rating==1000),isTrue);
    });
  }
  test('even leg format still finishes early with a decisive win', () {
    final c=ScorerController(ScorerSettings(startScore:40,bestOfLegs:4,participants:[const ScorerParticipant('A'),const ScorerParticipant('B')]));
    addTearDown(c.dispose);
    for(var i=0;i<3;i++) { if(c.activePlayer!=0) c.submitScore(0,checkoutAttempts:0); c.submitScore(40,checkoutDarts:1,checkoutAttempts:1); }
    expect(c.winner,0); expect(c.isDraw,isFalse); expect(c.legs,[3,0]);
  });
}
