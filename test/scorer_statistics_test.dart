import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_tournament_manager/features/scorer/application/scorer_controller.dart';
import 'package:dart_tournament_manager/features/scorer/domain/scorer_settings.dart';
import 'package:dart_tournament_manager/features/scorer/domain/x01/x01_rules.dart';
import 'package:dart_tournament_manager/features/scorer/presentation/widgets/scorer_statistics_view.dart';
import 'package:dart_tournament_manager/features/scorer/presentation/scorer_match_page.dart';
import 'package:dart_tournament_manager/features/scorer/presentation/widgets/score_keypad.dart';

void main() {
  ScorerController game({int start = 501, int legs = 1, int sets = 1}) =>
      ScorerController(
        ScorerSettings(
          startScore: start,
          bestOfLegs: legs,
          bestOfSets: sets,
          participants: const [
            ScorerParticipant('Anna'),
            ScorerParticipant('Ben'),
          ],
        ),
      );
  test('Empty match has no fabricated averages or percentages', () {
    final c = game();
    final p = c.statistics.players.first;
    expect(p.average, isNull);
    expect(p.firstNineAverage, isNull);
    expect(p.checkoutPercent, isNull);
    expect(p.bestLeg, isNull);
    c.dispose();
  });
  test('Nine darter, finish, scoring thresholds and undo', () {
    final c = game();
    for (var n = 0; n < 2; n++) {
      c.submitScore(180);
      c.submitScore(0);
    }
    c.submitScore(141, checkoutDarts: 3, checkoutAttempts: 1);
    var p = c.statistics.players.first;
    expect(p.average, 167);
    expect(p.firstNineAverage, 167);
    expect(p.darts, 9);
    expect(p.nineDarters, 1);
    expect(p.scores180, 2);
    expect(p.scores140, 3);
    expect(p.scores100, 3);
    expect(p.highestFinish, 141);
    expect(p.tonFinishes, 1);
    expect(p.bestLeg, 9);
    expect(p.holds, 1);
    expect(p.breaks, 0);
    expect(p.checkoutPercent, 100);
    expect(c.statistics.legs.single.finish, 141);
    c.undo();
    p = c.statistics.players.first;
    expect(p.points, 360);
    expect(p.legsWon, 0);
    expect(p.bestLeg, isNull);
    expect(c.statistics.legs, isEmpty);
    c.dispose();
  });
  test('Checkout dart count and weighted averages across legs and sets', () {
    final c = game(start: 40, sets: 3);
    c.submitScore(40, checkoutDarts: 1);
    c.submitScore(0, checkoutAttempts: 3); // Ben starts second leg.
    c.submitBust(checkoutAttempts: 2);
    c.submitScore(0, checkoutAttempts: 3);
    c.submitScore(40, checkoutDarts: 1);
    final p = c.statistics.players.first;
    expect(p.average, 48); // 80 / (1 + 3 + 1) * 3, not mean of leg averages.
    expect(p.legsWon, 2);
    expect(p.legsPlayed, 2);
    expect(p.busts, 1);
    expect(p.bestLeg, 1);
    expect(p.dartsPerWonLeg, 2.5);
    expect(p.checkoutAttempts, 4);
    expect(p.checkoutPercent, 50);
    expect(p.holds, 1);
    expect(p.breaks, 1);
    c.dispose();
  });
  test(
    'Unknown checkout attempts hide percentage instead of assuming zero',
    () {
      final c = game(start: 40);
      c.submitScore(0);
      c.submitScore(0, checkoutAttempts: 0);
      c.submitScore(40, checkoutDarts: 1);
      expect(c.statistics.players.first.checkoutPercent, isNull);
      expect(c.statistics.players.first.unknownCheckoutVisits, 1);
      c.undo();
      c.undo();
      c.undo();
      expect(c.statistics.players.first.unknownCheckoutVisits, 0);
      c.dispose();
    },
  );
  test(
    'First nine excludes later visits; losing darts remain in match average',
    () {
      final c = game();
      for (var n = 0; n < 4; n++) {
        c.submitScore(100);
        c.submitScore(60);
      }
      c.submitScore(101, checkoutDarts: 2, checkoutAttempts: 1);
      final stats = c.statistics;
      expect(stats.players[0].average, closeTo(501 * 3 / 14, .0001));
      expect(stats.players[0].firstNineAverage, 100);
      expect(stats.players[1].average, 60);
      expect(stats.players[1].darts, 12);
      expect(stats.players[1].dartsPerWonLeg, isNull);
      c.dispose();
    },
  );
  test('Invalid metadata leaves history and statistics unchanged', () {
    final c = game(start: 170);
    expect(
      () => c.submitScore(170, checkoutDarts: 3, checkoutAttempts: 2),
      throwsArgumentError,
    );
    expect(c.statistics.players.first.visits, 0);
    expect(c.canUndo, false);
    c.dispose();
  });
  test(
    'Observed early bust counts a full visit; intended checkout dart is recorded',
    () {
      final c = game(start: 40);
      c.throwDart(const X01Rules().createTriple(20), checkoutAttempt: false);
      expect(c.statistics.players.first.darts, 3);
      expect(c.statistics.players.first.points, 0);
      c.throwDart(const X01Rules().createMiss(), checkoutAttempt: true);
      c.throwDart(const X01Rules().createDouble(20), checkoutAttempt: true);
      expect(c.statistics.players[1].checkoutAttempts, 2);
      expect(c.statistics.players[1].checkoutPercent, 50);
      c.dispose();
    },
  );
  testWidgets('Statistics render on small screens without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final c = game();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ScorerStatisticsView(
            statistics: c.statistics,
            settings: c.settings,
          ),
        ),
      ),
    );
    expect(find.text('3-Dart-Average'), findsOneWidget);
    expect(tester.takeException(), isNull);
    c.dispose();
  });
  testWidgets(
    'Human checkout opportunities ask for real attempts and show live stats',
    (tester) async {
      final c = game(start: 40);
      await tester.pumpWidget(
        MaterialApp(home: ScorerMatchPage(settings: c.settings)),
      );
      final submitted = tester
          .widget<ScoreKeypad>(find.byType(ScoreKeypad))
          .onSubmit(0);
      await tester.pumpAndSettle();
      expect(find.text('Darts auf Checkout'), findsOneWidget);
      await tester.tap(find.text('2 Versuche'));
      await tester.pumpAndSettle();
      expect(await submitted, true);
      await tester.tap(find.byTooltip('Matchstatistik'));
      await tester.pumpAndSettle();
      expect(find.text('0 Treffer / 2 erfasst'), findsOneWidget);
      expect(tester.takeException(), isNull);
      c.dispose();
    },
  );
}
