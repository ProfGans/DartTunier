import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_tournament_manager/features/settings/presentation/settings_page.dart';

void main() {
  testWidgets('SettingsPage Daten tab loads without errors', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SettingsPage(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final datenTab = find.text('Daten');
    expect(datenTab, findsOneWidget);
    await tester.tap(datenTab);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Datensicherung'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
