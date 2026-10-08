import 'support/scorer_setup_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_tournament_manager/features/scorer/presentation/scorer_page.dart';
import 'package:dart_tournament_manager/features/scorer/presentation/scorer_match_page.dart';
import 'package:dart_tournament_manager/features/scorer/domain/scorer_settings.dart';
import 'package:dart_tournament_manager/features/scorer/domain/bot_settings.dart';
import 'package:dart_tournament_manager/features/scorer/data/bot_settings_storage.dart';
import 'package:dart_tournament_manager/features/scorer/data/repositories/checkout_route_repository.dart';
import 'package:dart_tournament_manager/features/scorer/presentation/widgets/score_keypad.dart';

void main() {
  testWidgets('Scorer exposes checkout calculator and fixed 170 finish', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: ScorerPage(botStorage: _BotStorage())),
    );
    await tester.scrollUntilVisible(
      find.text('Checkoutrechner'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Checkoutrechner'));
    await tester.pumpAndSettle();
    expect(find.text('1.  T20 → T20 → BULL'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Dart input ends a match and undo reopens it', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ScorerMatchPage(
          settings: ScorerSettings(
            startScore: 40,
            bestOfLegs: 1,
            participants: const [
              ScorerParticipant('Anna'),
              ScorerParticipant('Ben'),
            ],
          ),
        ),
      ),
    );
    await Scrollable.ensureVisible(
      tester.element(find.text('4')),
      alignment: .5,
    );
    await tester.pump();
    await tester.tap(find.text('4'));
    await tester.pump();
    await Scrollable.ensureVisible(
      tester.element(find.text('0')),
      alignment: .5,
    );
    await tester.pump();
    await tester.tap(find.text('0'));
    await tester.pump();
    await Scrollable.ensureVisible(
      tester.element(find.text('OK')),
      alignment: .5,
    );
    await tester.pump();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('1 Dart'));
    await tester.pumpAndSettle();
    expect(find.text('Anna gewinnt!'), findsOneWidget);
    await tester.scrollUntilVisible(find.byTooltip('Rückgängig'), 250);
    await Scrollable.ensureVisible(
      tester.element(find.byTooltip('Rückgängig')),
      alignment: .5,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Rückgängig'));
    await tester.pump();
    expect(find.text('Anna gewinnt!'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'Bot entry starts match with saved tuning and responds to calculator visit',
    (tester) async {
      await tester.runAsync(
        () => CheckoutRouteRepository.instance.initialize(),
      );
      await tester.pumpWidget(
        MaterialApp(home: ScorerPage(botStorage: _BotStorage())),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Gegen Bot spielen'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await Scrollable.ensureVisible(
        tester.element(find.text('Gegen Bot spielen')),
        alignment: .5,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Gegen Bot spielen'));
      await tester.pumpAndSettle();
      await scorerSetupReview(tester);
      await tester.scrollUntilVisible(
        find.text('Spiel starten'),
        350,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Spiel starten'));
      await tester.pumpAndSettle();
      final page = tester.widget<ScorerMatchPage>(find.byType(ScorerMatchPage));
      final profile = page.settings.participants[1].bot!;
      expect(profile.skill, 750);
      expect(profile.finishingSkill, 650);
      expect(profile.radiusCalibrationPercent, 94);
      expect(page.settings.botThrowDelay, const Duration(milliseconds: 250));
      await Scrollable.ensureVisible(
        tester.element(find.text('100')),
        alignment: .5,
      );
      await tester.pump();
      await tester.tap(find.text('100'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1));
      expect(
        tester.widget<ScoreKeypad>(find.byType(ScoreKeypad)).enabled,
        false,
      );
      for (var n = 0; n < 4; n++) {
        await tester.pump(const Duration(milliseconds: 260));
      }
      expect(
        tester.widget<ScoreKeypad>(find.byType(ScoreKeypad)).enabled,
        true,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('Calculator fits narrow screens and supports clearing input', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    int? score;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ScoreKeypad(
            enabled: true,
            remaining: 501,
            onSubmit: (value) async {
              score = value;
              return true;
            },
            onBust: () {},
          ),
        ),
      ),
    );
    await tester.tap(find.text('1'));
    await tester.pump();
    await tester.tap(find.text('2'));
    await tester.pump();
    await tester.tap(find.byTooltip('Letzte Ziffer löschen'));
    await tester.pump();
    await Scrollable.ensureVisible(
      tester.element(find.text('0')),
      alignment: .5,
    );
    await tester.pump();
    await tester.tap(find.text('0'));
    await tester.pump();
    await Scrollable.ensureVisible(
      tester.element(find.text('OK')),
      alignment: .5,
    );
    await tester.pump();
    await tester.tap(find.text('OK'));
    await tester.pump();
    expect(score, 10);
    expect(tester.takeException(), isNull);
  });
}

class _BotStorage extends BotSettingsStorage {
  @override
  Future<BotSettings> load() async => const BotSettings(
    skill: 750,
    finishingSkill: 650,
    radiusPercent: 110,
    spreadPercent: 90,
    speedIndex: 2,
    useTheoAverage: false,
  );
}
