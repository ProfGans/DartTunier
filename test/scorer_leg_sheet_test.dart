import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_tournament_manager/features/scorer/application/scorer_controller.dart';
import 'package:dart_tournament_manager/features/scorer/domain/scorer_settings.dart';
import 'package:dart_tournament_manager/features/scorer/presentation/widgets/scorer_leg_sheet.dart';

void main() {
  for (final size in [
    const Size(360, 800),
    const Size(800, 600),
    const Size(1440, 900),
  ]) {
    testWidgets('Leg sheet shows scores, busts and resets at $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final c = ScorerController(
        ScorerSettings(
          startScore: 101,
          participants: const [
            ScorerParticipant('Anna mit einem sehr langen Namen'),
            ScorerParticipant('Ben'),
          ],
        ),
      );
      addTearDown(c.dispose);
      c.submitScore(60, checkoutAttempts: 0);
      c.submitBust(checkoutAttempts: 0);
      Future<void> render() => tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MediaQuery(
              data: MediaQueryData(
                size: size,
                textScaler: const TextScaler.linear(2),
              ),
              child: SingleChildScrollView(
                child: ScorerLegSheet(
                  settings: c.settings,
                  visits: c.statisticsVisits,
                  leg: c.displayedLeg,
                  starter: c.legStarter,
                ),
              ),
            ),
          ),
        ),
      );
      await render();
      expect(find.text('60 → 41'), findsOneWidget);
      expect(find.text('0 → 101\nÜberworfen'), findsOneWidget);
      expect(tester.takeException(), isNull);
      c.submitScore(41, checkoutDarts: 2, checkoutAttempts: 1);
      await render();
      expect(find.text('Schreibertafel · Leg 2'), findsOneWidget);
      expect(find.text('60 → 41'), findsNothing);
      c.undo();
      await render();
      expect(find.text('Schreibertafel · Leg 1'), findsOneWidget);
      expect(find.text('60 → 41'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('Winning leg remains visible with checkout', (tester) async {
    final c = ScorerController(
      ScorerSettings(
        startScore: 40,
        bestOfLegs: 1,
        participants: const [
          ScorerParticipant('Anna'),
          ScorerParticipant('Ben'),
        ],
      ),
    );
    addTearDown(c.dispose);
    c.submitScore(40, checkoutDarts: 1, checkoutAttempts: 1);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ScorerLegSheet(
            settings: c.settings,
            visits: c.statisticsVisits,
            leg: c.displayedLeg,
            starter: c.legStarter,
          ),
        ),
      ),
    );
    expect(find.text('Schreibertafel · Leg 1'), findsOneWidget);
    expect(find.text('40 → 0\nCheckout · 1 Dart'), findsOneWidget);
  });
}
