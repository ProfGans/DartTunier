import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dart_tournament_manager/features/scorer/domain/scorer_hit.dart';
import 'package:dart_tournament_manager/features/statistics/data/scorer_heatmap_repository.dart';
import 'package:dart_tournament_manager/features/autoscoring/presentation/widgets/scorer_camera_panel.dart';
import 'package:dart_tournament_manager/features/autoscoring/application/autoscoring_controller.dart';
import 'package:dart_tournament_manager/features/scorer/application/scorer_controller.dart';
import 'package:dart_tournament_manager/features/scorer/domain/scorer_settings.dart';
import 'package:dart_tournament_manager/features/scorer/domain/x01/x01_rules.dart';
import 'package:dart_tournament_manager/features/scorer/domain/x01/x01_models.dart';
import 'package:dart_tournament_manager/features/scorer/presentation/scorer_match_page.dart';

void main() {
  testWidgets('Camera panel survives desktop to phone layout changes', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 900);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: ScorerMatchPage(
          settings: ScorerSettings(
            participants: const [
              ScorerParticipant('A'),
              ScorerParticipant('B'),
            ],
          ),
        ),
      ),
    );
    await tester.tap(find.byTooltip('Autoscorer · drei Kameras'));
    await tester.pumpAndSettle();
    final original = tester.state(find.byType(ScorerCameraPanel));
    tester.view.physicalSize = const Size(360, 800);
    await tester.pumpAndSettle();
    expect(
      identical(tester.state(find.byType(ScorerCameraPanel)), original),
      true,
    );
    tester.view.physicalSize = const Size(1440, 900);
    await tester.pumpAndSettle();
    expect(
      identical(tester.state(find.byType(ScorerCameraPanel)), original),
      true,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('Live rest and inferred checkout attempts commit on removal', (
    tester,
  ) async {
    ScorerController? finished;
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      MaterialApp(
        home: ScorerMatchPage(
          settings: ScorerSettings(
            startScore: 40,
            bestOfLegs: 1,
            participants: const [
              ScorerParticipant('A'),
              ScorerParticipant('B'),
            ],
          ),
          onCompleted: (c) => finished = c,
        ),
      ),
    );
    await tester.tap(find.byTooltip('Autoscorer · drei Kameras'));
    await tester.pumpAndSettle();
    final first = const X01Rules().createSingle(20);
    final last = const X01Rules().createDouble(10);
    var panel = tester.widget<ScorerCameraPanel>(
      find.byType(ScorerCameraPanel),
    );
    panel.onLocations!([const DartLocation(0, -120)]);
    panel.onPreview!([first], [null]);
    await tester.pump();
    expect(find.text('20'), findsWidgets);
    panel = tester.widget<ScorerCameraPanel>(find.byType(ScorerCameraPanel));
    expect(panel.attempts, [true]);
    panel.onLocations!([
      const DartLocation(0, -120),
      const DartLocation(166, 0, corrected: true),
    ]);
    panel.onPreview!([first, last], [null, null]);
    await tester.pump();
    expect(finished, isNull);
    expect(await ScorerHeatmapRepository().load(), isEmpty);
    panel = tester.widget<ScorerCameraPanel>(find.byType(ScorerCameraPanel));
    expect(panel.attempts, [true, true]);
    panel.onAccept([]);
    await tester.pump();
    expect(finished!.statistics.players.first.checkoutPercent, 50);
    expect(find.text('A gewinnt!'), findsOneWidget);
    final saved = await ScorerHeatmapRepository().load();
    expect(saved.single.hits.length, 2);
    expect(saved.single.hits.last.location.corrected, true);
    expect(saved.single.complete, true);
    await tester.pumpWidget(const SizedBox());
  });
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
    tester.widget<ScorerCameraPanel>(find.byType(ScorerCameraPanel)).onPreview!(
      [
        const X01Rules().createSingle(20),
        const X01Rules().createSingle(20),
        const X01Rules().createSingle(20),
      ],
      [null, null, null],
    );
    tester
        .widget<ScorerCameraPanel>(find.byType(ScorerCameraPanel))
        .onAccept([]);
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
        camera.onPreview!([const X01Rules().createDouble(20)], [null]);
        expect(completed, isFalse);
        camera.onAccept([]);
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
