import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_tournament_manager/features/devices/presentation/device_scorer_session.dart';
import 'package:dart_tournament_manager/features/devices/domain/board_display.dart';
import 'package:dart_tournament_manager/features/devices/data/board_display_server.dart';
import 'package:dart_tournament_manager/features/tournaments/data/tournament_storage.dart';
import 'package:dart_tournament_manager/features/tournaments/domain/tournament_models.dart';
import 'package:dart_tournament_manager/features/scorer/presentation/scorer_match_page.dart';
import 'package:dart_tournament_manager/features/scorer/application/scorer_controller.dart';

class MemoryResults extends TournamentStorage {
  final rows = <String,List<dynamic>>{};
  @override
  Future<List<dynamic>?> readCache(String key) async => rows[key];
  @override
  Future<void> writeCache(String key,List<dynamic> value) async { rows[key]=value; }
}
void main() {
  testWidgets('completed scorer persists visits and restores its pending result', (tester) async {
    final receiver = BoardDisplayServer();
    addTearDown(receiver.dispose);
    final storage = MemoryResults();
    const display = BoardDisplay(tournamentId:'cup',tournamentName:'Cup',board:1,state:'running',
      matchId:'finished-match',home:'Anna',away:'Ben',gameFormat:TournamentGameFormat(x01Score:40,bestOfLegs:1));
    receiver.display = display;
    Widget app() => MaterialApp(home:DeviceScorerSession(display:display,receiver:receiver,storage:storage,onExit:() {}));
    await tester.pumpWidget(app()); await tester.pumpAndSettle();
    final scorer = tester.widget<ScorerMatchPage>(find.byType(ScorerMatchPage));
    final controller = ScorerController(scorer.settings);
    addTearDown(controller.dispose);
    controller.submitScore(40,checkoutDarts:1,checkoutAttempts:1);
    expect(controller.winner,0);
    scorer.onCompleted!(controller);
    await tester.pumpAndSettle();
    expect(receiver.completedResult!['legs'],[1,0]);
    expect((receiver.completedResult!['statistics'] as Map)['visits'],hasLength(1));
    expect(storage.rows,hasLength(1));
    await tester.pumpWidget(const SizedBox());
    receiver.completedResult=null;
    await tester.pumpWidget(app()); await tester.pumpAndSettle();
    expect(receiver.completedResult!['matchId'],'finished-match');
    expect(find.byType(ScorerMatchPage),findsNothing);
    expect(tester.takeException(),isNull);
  });
  testWidgets('incoming game retains scorer across polling and responsive resizing', (tester) async {
    final receiver = BoardDisplayServer();
    addTearDown(receiver.dispose);
    final storage = MemoryResults();
    const display = BoardDisplay(tournamentId:'cup',tournamentName:'Cup',board:1,state:'running',
      matchId:'match-1',home:'Anna Musterfrau',away:'Ben Beispielmann',gameFormat:TournamentGameFormat(x01Score:301,bestOfLegs:5));
    receiver.display=display;
    tester.view.devicePixelRatio=1;
    addTearDown(tester.view.reset);
    Widget app() => MaterialApp(builder: (context,child) => MediaQuery(
      data:MediaQuery.of(context).copyWith(textScaler:TextScaler.linear(2)),child:child!),
      home:DeviceScorerSession(key:const ValueKey('match-1'),display:display,receiver:receiver,storage:storage,onExit:() {}));
    await tester.pumpWidget(app()); await tester.pumpAndSettle();
    final scorerState = tester.state(find.byType(ScorerMatchPage));
    for (final size in [const Size(360,800),const Size(800,600),const Size(1440,900)]) {
      tester.view.physicalSize=size;
      await tester.pumpWidget(app()); await tester.pumpAndSettle();
      expect(tester.state(find.byType(ScorerMatchPage)),same(scorerState));
      expect(find.textContaining('Anna Musterfrau'), findsWidgets);
      expect(tester.takeException(),isNull);
    }
  });
}
