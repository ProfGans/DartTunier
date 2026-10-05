import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_tournament_manager/features/scorer/presentation/widgets/scorer_doubles_dialog.dart';
import 'package:dart_tournament_manager/features/scorer/application/scorer_controller.dart';
import 'package:dart_tournament_manager/features/scorer/domain/scorer_settings.dart';

void main() {
  test('Doubles share a score and alternate members on their visits', () {
    final c = ScorerController(
      ScorerSettings(
        participants: const [
          ScorerParticipant('A / B', members: ['A', 'B']),
          ScorerParticipant('C / D', members: ['C', 'D']),
        ],
      ),
    );
    expect(c.activeThrower, 'A');
    c.submitScore(60);
    expect(c.activeThrower, 'C');
    c.submitScore(45);
    expect(c.activeThrower, 'B');
    expect(c.remaining, 441);
    c.submitScore(100);
    expect(c.activeThrower, 'D');
    c.undo();
    expect(c.activeThrower, 'B');
    c.dispose();
  });
  for (final size in [
    const Size(360, 800),
    const Size(800, 600),
    const Size(1440, 900),
  ]) {
    testWidgets('Local doubles dialog at $size with large text', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      List<String>? result;
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await showDialog<List<String>>(
                    context: context,
                    builder: (_) => const ScorerDoublesDialog(
                      first: 'Anna',
                      allowCommunity: true,
                    ),
                  );
                },
                child: const Text('Team'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Team'));
      await tester.pumpAndSettle();
      expect(find.text('Aus Community auswählen'), findsNWidgets(2));
      await tester.enterText(find.byType(TextFormField).last, 'Ben');
      await Scrollable.ensureVisible(
        tester.element(find.text('Doppelteam übernehmen')),
        alignment: .5,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Doppelteam übernehmen'));
      await tester.pumpAndSettle();
      expect(result, ['Anna', 'Ben']);
      expect(tester.takeException(), isNull);
    });
  }
}
