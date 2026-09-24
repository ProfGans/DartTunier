import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_tournament_manager/features/dev_tools/presentation/dev_tools_page.dart';
import 'package:dart_tournament_manager/tournament_workspace.dart'
    show TournamentFormatPlannerDialog;

void main() {
  testWidgets('random controls appear on demand and validate input', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: DevToolsPage()));
    expect(find.byKey(const ValueKey('dev-random-seed')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('dev-random-mode')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('dev-random-seed')), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('dev-random-count')), '0');
    await tester.ensureVisible(find.text('Zufallsturniere testen'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Zufallsturniere testen'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Bitte 1–100 Turniere'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('planner requires manual opt-in for sets each time it opens', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: TournamentFormatPlannerDialog()),
    );
    final toggle = find.byKey(const ValueKey('planner-allow-sets'));
    await tester.ensureVisible(toggle);
    expect(tester.widget<SwitchListTile>(toggle).value, isFalse);
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(tester.widget<SwitchListTile>(toggle).value, isTrue);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
      const MaterialApp(home: TournamentFormatPlannerDialog()),
    );
    expect(tester.widget<SwitchListTile>(toggle).value, isFalse);
  });
}
