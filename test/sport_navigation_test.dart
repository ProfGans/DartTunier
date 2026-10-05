import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_tournament_manager/app/app_theme.dart';
import 'package:dart_tournament_manager/app/navigation/sport_app_shell.dart';

void main() {
  for (final size in [
    const Size(360, 800),
    const Size(800, 600),
    const Size(1440, 900),
  ]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('Sport navigation $size / $scale keeps inputs on resize', (
        tester,
      ) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = size;
        addTearDown(tester.view.reset);
        var selected = -1;
        await tester.pumpWidget(
          MaterialApp(
            theme: buildDartTournamentTheme(),
            home: MediaQuery(
              data: MediaQueryData(
                size: size,
                textScaler: TextScaler.linear(scale),
              ),
              child: SportAppShell(
                destinations: [
                  SportDestination(
                    'Übersicht',
                    Icons.dashboard,
                    () => selected = 0,
                  ),
                  SportDestination(
                    'Turniere',
                    Icons.emoji_events,
                    () => selected = 1,
                  ),
                ],
                child: const Scaffold(
                  body: SingleChildScrollView(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: TextField(
                        decoration: InputDecoration(labelText: 'Turniername'),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.enterText(find.byType(TextField), 'Sportcup');
        if (size.width >= 1100 && scale == 1) {
          await tester.tap(find.text('Turniere'));
        } else {
          await tester.tap(find.byTooltip('Bereich wechseln'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Turniere'));
        }
        await tester.pumpAndSettle();
        expect(selected, 1);
        tester.view.physicalSize = size.width < 1100
            ? const Size(1440, 900)
            : const Size(360, 800);
        await tester.pumpAndSettle();
        expect(find.text('Sportcup'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
