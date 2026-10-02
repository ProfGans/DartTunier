import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_tournament_manager/features/scorer/application/scorer_controller.dart';
import 'package:dart_tournament_manager/features/scorer/domain/scorer_settings.dart';
import 'package:dart_tournament_manager/features/scorer/presentation/widgets/scorer_result_view.dart';

void main() {
  for (final size in [
    const Size(360, 800),
    const Size(800, 600),
    const Size(1440, 900),
  ]) {
    testWidgets('Result fits $size with large text and correction', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final c = ScorerController(
        ScorerSettings(
          startScore: 40,
          bestOfLegs: 1,
          participants: const [
            ScorerParticipant('Anna mit einem sehr langen Namen'),
            ScorerParticipant('Ben'),
          ],
        ),
      );
      addTearDown(c.dispose);
      c.submitScore(40, checkoutDarts: 1, checkoutAttempts: 1);
      var closed = false;
      var details = false;
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: Scaffold(
            body: ScorerResultView(
              settings: c.settings,
              statistics: c.statistics,
              sets: c.sets,
              winner: c.winner,
              onUndo: c.undo,
              onClose: () => closed = true,
              onStatistics: () => details = true,
            ),
          ),
        ),
      );
      expect(
        find.text('Anna mit einem sehr langen Namen gewinnt!'),
        findsOneWidget,
      );
      await tester.scrollUntilVisible(find.text('100,00 %'), 200);
      expect(find.text('100,00 %'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Alle Statistiken'), 250);
      await Scrollable.ensureVisible(
        tester.element(find.text('Alle Statistiken')),
        alignment: .5,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Alle Statistiken'));
      expect(details, isTrue);
      await Scrollable.ensureVisible(
        tester.element(find.text('Letzte Eingabe korrigieren')),
        alignment: .5,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Letzte Eingabe korrigieren'));
      expect(c.isComplete, isFalse);
      await Scrollable.ensureVisible(
        tester.element(find.text('Spiel abschließen')),
        alignment: .5,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Spiel abschließen'));
      expect(closed, isTrue);
      expect(tester.takeException(), isNull);
    });
  }
}
