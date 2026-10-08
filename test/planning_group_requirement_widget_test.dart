import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_tournament_manager/tournament_workspace.dart';

void main() {
  for (final size in [
    const Size(360, 800),
    const Size(800, 600),
    const Size(1440, 900),
  ]) {
    testWidgets('optional group phase at $size with large text', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(2)),
            child: child!,
          ),
          home: const Scaffold(body: TournamentFormatPlannerDialog()),
        ),
      );
      await tester.ensureVisible(find.text('Turnierformen'));
      await tester.tap(find.text('Turnierformen'));
      await tester.pumpAndSettle();
      final option = find.byKey(const ValueKey('planner-require-groups'));
      final mode = find.byKey(const ValueKey('planner-mode-single_knockout'));
      await tester.ensureVisible(mode);
      await tester.pumpAndSettle();
      expect(tester.widget<CheckboxListTile>(mode).value, isTrue);
      await tester.tap(mode);
      await tester.pumpAndSettle();
      expect(tester.widget<CheckboxListTile>(mode).value, isFalse);
      await tester.ensureVisible(find.text('Aufbau & Gruppen'));
      await tester.tap(find.text('Aufbau & Gruppen'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(option);
      await tester.pumpAndSettle();
      expect(tester.widget<SwitchListTile>(option).value, isFalse);
      await tester.tap(option);
      await tester.pumpAndSettle();
      expect(tester.widget<SwitchListTile>(option).value, isTrue);
      expect(tester.takeException(), isNull);
    });
  }
}
