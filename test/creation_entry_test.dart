import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_tournament_manager/tournament_workspace.dart';

void main() {
  for (final size in [
    const Size(360, 800),
    const Size(800, 600),
    const Size(1440, 900),
  ]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('creation choices $size scale $scale', (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = size;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: const TournamentCreationPage(),
          ),
        );
        final finder = find.text('Turnierform finden');
        await tester.scrollUntilVisible(
          finder,
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        await tester.tap(finder);
        await tester.pumpAndSettle();
        expect(find.text('Passende Turnierform finden'), findsOneWidget);
        Navigator.of(tester.element(find.byType(AlertDialog))).pop();
        await tester.pumpAndSettle();
        final expert = find.text('Expertenmodus');
        await tester.scrollUntilVisible(
          expert,
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        await tester.tap(expert);
        await tester.pumpAndSettle();
        expect(expert, findsNothing);
        expect(find.byType(TextField), findsWidgets);
        await tester.scrollUntilVisible(
          find.text('Geräte hinzufügen / verwalten'),
          500,
          scrollable: find.byType(Scrollable).first,
          maxScrolls: 40,
        );
        await tester.pumpAndSettle();
        expect(find.text('Geräte vorbereiten'), findsOneWidget);
        tester.view.physicalSize = const Size(360, 800);
        await tester.pumpAndSettle();
        expect(expert, findsNothing);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
