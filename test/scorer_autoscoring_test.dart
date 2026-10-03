import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_tournament_manager/features/autoscoring/presentation/widgets/scorer_camera_panel.dart';
import 'package:dart_tournament_manager/features/autoscoring/application/autoscoring_controller.dart';
import 'package:dart_tournament_manager/features/scorer/application/scorer_controller.dart';
import 'package:dart_tournament_manager/features/scorer/domain/scorer_settings.dart';
import 'package:dart_tournament_manager/features/scorer/domain/x01/x01_rules.dart';
import 'package:dart_tournament_manager/features/scorer/domain/x01/x01_models.dart';
import 'package:dart_tournament_manager/features/scorer/presentation/scorer_match_page.dart';

void main() {
  testWidgets('Bots finish their turns without any camera confirmation', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ScorerMatchPage(
          settings: ScorerSettings(
            botThrowDelay: const Duration(milliseconds: 20),
            participants: const [
              ScorerParticipant('Human'),
              ScorerParticipant(
                'Bot 1',
                bot: BotProfile(skill: 50, finishingSkill: 50),
              ),
              ScorerParticipant(
                'Bot 2',
                bot: BotProfile(skill: 50, finishingSkill: 50),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.tap(find.byTooltip('Autoscorer · drei Kameras'));
    await tester.pumpAndSettle();
    tester.widget<ScorerCameraPanel>(find.byType(ScorerCameraPanel)).onAccept([
      const X01Rules().createSingle(20),
      const X01Rules().createSingle(20),
      const X01Rules().createSingle(20),
    ]);
    await tester.pump();
    expect(
      tester.widget<ScorerCameraPanel>(find.byType(ScorerCameraPanel)).enabled,
      isFalse,
    );
    // Both bots must play all three darts even with no camera connected.
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 25));
    }
    expect(
      tester.widget<ScorerCameraPanel>(find.byType(ScorerCameraPanel)).enabled,
      isTrue,
    );
    expect(find.textContaining('Human ist am Wurf'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  for (final device in [false, true]) {
    testWidgets(
      'Automatic camera scoring in ${device ? 'device' : 'local'} match',
      (tester) async {
        final settings = ScorerSettings(
          startScore: 40,
          bestOfLegs: 1,
          participants: const [
            ScorerParticipant('Anna'),
            ScorerParticipant('Ben'),
          ],
        );
        var completed = false;
        await tester.pumpWidget(
          MaterialApp(
            home: ScorerMatchPage(
              settings: settings,
              onExit: device ? () {} : null,
              onCompleted: (_) => completed = true,
            ),
          ),
        );
        await tester.tap(find.byTooltip('Autoscorer · drei Kameras'));
        await tester.pumpAndSettle();
        final camera = tester.widget<ScorerCameraPanel>(
          find.byType(ScorerCameraPanel),
        );
        expect(camera.dartsLeft, 3);
        camera.onAccept([const X01Rules().createDouble(20)]);
        expect(completed, isTrue);
        camera.onAccept([const X01Rules().createSingle(20)]);
        await tester.pumpAndSettle();
        expect(find.text('Anna gewinnt!'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
  test('Autoscoring misses survive saved session replay', () {
    final settings = ScorerSettings(
      participants: const [ScorerParticipant('A'), ScorerParticipant('B')],
    );
    final game = ScorerController(settings);
    game.throwDart(AutoscoringController.bouncerThrow);
    game.throwDart(AutoscoringController.unresolvedThrow);
    final restored = ScorerController(settings)
      ..restoreActions(game.exportActions());
    expect(restored.visit.map((d) => d.label), ['Bouncer', 'Nicht erkannt']);
    expect(restored.dartsLeft, 1);
    game.dispose();
    restored.dispose();
  });
}
