import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_tournament_manager/app/app_theme.dart';
import 'package:dart_tournament_manager/features/scorer/presentation/scorer_match_page.dart';
import 'package:dart_tournament_manager/features/scorer/presentation/widgets/score_keypad.dart';
import 'package:dart_tournament_manager/features/scorer/domain/scorer_settings.dart';

void main() {
  testWidgets('mobile touch entry survives switching to desktop and rotation', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 800);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildDartTournamentTheme(),
        home: ScorerMatchPage(
          settings: ScorerSettings(
            participants: const [
              ScorerParticipant('Anna'),
              ScorerParticipant('Ben'),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    for (final digit in ['4', '1']) {
      await Scrollable.ensureVisible(
        tester.element(find.text(digit)),
        alignment: .5,
      );
      await tester.pump();
      final button = find.ancestor(
        of: find.text(digit),
        matching: find.byType(OutlinedButton),
      );
      expect(tester.getSize(button).width, greaterThanOrEqualTo(48));
      expect(tester.getSize(button).height, greaterThanOrEqualTo(48));
      await tester.tap(find.text(digit));
      await tester.pump();
    }
    final state = tester.state(find.byType(ScoreKeypad));
    for (final size in [
      const Size(1440, 900),
      const Size(800, 600),
      const Size(320, 568),
    ]) {
      tester.view.physicalSize = size;
      await tester.pumpAndSettle();
      expect(tester.state(find.byType(ScoreKeypad)), same(state));
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('score-display'))).data,
        '41',
      );
      expect(tester.takeException(), isNull);
    }
  });
}
