import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_tournament_manager/features/devices/application/device_scorer_settings.dart';
import 'package:dart_tournament_manager/features/devices/application/device_result_importer.dart';
import 'package:dart_tournament_manager/features/devices/application/board_display_projector.dart';
import 'package:dart_tournament_manager/features/devices/data/board_display_client.dart';
import 'package:dart_tournament_manager/features/devices/data/board_display_server.dart';
import 'package:dart_tournament_manager/features/devices/data/device_link_auth.dart';
import 'package:dart_tournament_manager/features/devices/domain/board_display.dart';
import 'package:dart_tournament_manager/features/scorer/domain/x01/x01_models.dart';
import 'package:dart_tournament_manager/features/statistics/domain/tournament_player_statistics.dart';
import 'package:dart_tournament_manager/features/tournaments/domain/tournament_models.dart';
import 'package:dart_tournament_manager/features/tournaments/application/order_of_play/order_of_play_controller.dart';

void main() {
  test('structured format preserves names, sets, double-in and every checkout rule', () {
    for (final rule in ['single_out', 'double_out', 'master_out']) {
      final display = BoardDisplay.fromJson(BoardDisplay(tournamentId: 't', tournamentName: 'Cup', board: 1,
        state: 'running', home: 'Anna', away: 'Ben', matchId: 'm',
        gameFormat: TournamentGameFormat(x01Score: 301, doubleIn: true, checkoutType: rule, bestOfLegs: 5, bestOfSets: 3)).toJson());
      final settings = deviceScorerSettings(display);
      expect(settings.participants.map((p) => p.name), ['Anna', 'Ben']);
      expect(settings.startScore, 301); expect(settings.bestOfLegs, 5); expect(settings.bestOfSets, 3);
      expect(settings.startRequirement, StartRequirement.doubleIn);
      expect(settings.checkoutRequirement.name, '${rule.split('_').first}Out');
    }
  });
  test('authenticated result survives repeated polling and has a signed payload', () async {
    final server = BoardDisplayServer(port: 0, bindAddress: InternetAddress.loopbackIPv4);
    addTearDown(server.dispose);
    final key = DeviceLinkAuth.newKey();
    const target = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
    await server.configure(deviceId: target, key: key, enabled: true);
    const display = BoardDisplay(tournamentId: 't', tournamentName: 'Cup', board: 1, state: 'running', matchId: 'm');
    Future<Map<String,dynamic>?> poll() => BoardDisplayClient().send(address:'127.0.0.1', targetId:target,
      sourceId:'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb', key:key, display:display, port:server.localPort!);
    expect(await poll(), isNull);
    server.completeMatch({'matchId':'m','legs':[2,0]});
    expect((await poll())!['legs'], [2,0]);
    expect((await poll())!['legs'], [2,0]);
    expect(() => server.completeMatch({'matchId':'other'}), throwsStateError);
  });
  test('result import keeps statistics, rejects stale assignments and is idempotent', () {
    const a = TournamentPlayer(name: 'Anna', profileId: 'a', isGenerated: false);
    const b = TournamentPlayer(name: 'Ben', profileId: 'b', isGenerated: false);
    final match = GroupMatch(homePlayer:a, awayPlayer:b, round:1);
    const format = TournamentGameFormat(x01Score:40, bestOfLegs:1);
    final tournament = CreatedTournament(name:'Cup', players:[a,b], stages:[const TournamentStage(name:'Finale',type:'single_knockout',gameFormat:format)],
      runStages:[KnockoutTournamentRunStage(name:'Finale',rounds:[[match]])]);
    const OrderOfPlayController().start(tournament,0,match,1);
    final id = const BoardDisplayProjector().project(tournament,0)[1]!.matchId;
    final result = <String,dynamic>{'version':1,'matchId':id,'legs':[1,0],'sets':[0,0], 'statistics':{
      'schemaVersion':1,'id':id,'accountId':'','playedAt':DateTime.now().toIso8601String(),'playerIndex':0,
      'names':['Anna','Ben'],'startScores':[40,40],'standard501Rules':true,'doubleOut':true,'winner':0,
      'visits':[{'player':0,'leg':0,'starter':0,'points':40,'darts':1,'remaining':0,'bust':false,'checkoutAttempts':1}]
    }};
    const importer = DeviceResultImporter();
    expect(importer.validate(tournament,result),same(match));
    importer.apply(match,result,format);
    expect(importer.validate(tournament,result),same(match));
    final restored = CreatedTournament.fromJson(tournament.toJson());
    final rows = const TournamentStatisticsCalculator().calculate([restored,restored]);
    expect(rows.first.matches,1); expect(rows.first.average,120); expect(rows.first.checkoutPercent,100);
    expect(() => importer.validate(tournament,{...result,'matchId':'stale'}),throwsStateError);
  });
}
