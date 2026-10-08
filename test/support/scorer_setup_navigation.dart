import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_tournament_manager/features/scorer/presentation/widgets/scorer_setup_wizard.dart';

Future<void> scorerSetupNext(WidgetTester tester) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(
    find.text('Weiter'),
    250,
    scrollable: find.byType(Scrollable).first,
    maxScrolls: 80,
  );
  await Scrollable.ensureVisible(
    tester.element(find.text('Weiter')),
    alignment: .5,
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Weiter'));
  await tester.pumpAndSettle();
}

Future<void> scorerSetupReview(WidgetTester tester) async {
  while (tester.widget<ScorerSetupWizard>(find.byType(ScorerSetupWizard)).step <
      2) {
    final previous = tester
        .widget<ScorerSetupWizard>(find.byType(ScorerSetupWizard))
        .step;
    await scorerSetupNext(tester);
    expect(
      tester.widget<ScorerSetupWizard>(find.byType(ScorerSetupWizard)).step,
      previous + 1,
    );
  }
}
