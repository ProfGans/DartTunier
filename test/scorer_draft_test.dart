import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dart_tournament_manager/features/scorer/application/scorer_controller.dart';
import 'package:dart_tournament_manager/features/scorer/data/scorer_draft_storage.dart';
import 'package:dart_tournament_manager/features/scorer/domain/scorer_settings.dart';
import 'package:dart_tournament_manager/features/scorer/domain/x01/x01_rules.dart';
import 'package:dart_tournament_manager/features/scorer/domain/x01/x01_models.dart';
import 'package:dart_tournament_manager/features/scorer/presentation/scorer_match_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  final settings = ScorerSettings(
    participants: const [ScorerParticipant('Anna'), ScorerParticipant('Ben')],
  );
  test('Bot settings, leg transitions and bot undo survive a checkpoint', () {
    final game = ScorerController(
      ScorerSettings(
        startScore: 40,
        bestOfLegs: 3,
        bestOfSets: 3,
        participants: const [
          ScorerParticipant('Anna'),
          ScorerParticipant(
            'Bot',
            bot: BotProfile(skill: 60, finishingSkill: 55),
          ),
        ],
      ),
    );
    game.submitScore(40, checkoutDarts: 1, checkoutAttempts: 1);
    game.throwDart(const X01Rules().createSingle(0), checkoutAttempt: true);
    final settingsCopy = ScorerDraftStorage.decodeSettings(
      ScorerDraftStorage.encodeSettings(game.settings),
    );
    final restored = ScorerController(settingsCopy)
      ..restoreActions(game.exportActions());
    expect(restored.legs, [1, 0]);
    expect(restored.isBotTurn, isTrue);
    expect(restored.dartsLeft, 2);
    expect(restored.settings.participants.last.bot!.finishingSkill, 55);
    restored.undo();
    expect(restored.legs, [0, 0]);
    expect(restored.activePlayer, 0);
    expect(restored.remaining, 40);
    game.dispose();
    restored.dispose();
  });
  test(
    'Checkpoint retains scores, partial visit, statistics and undo',
    () async {
      final original = ScorerController(settings);
      original.submitScore(100);
      original.submitBust();
      original.throwDart(const X01Rules().createTriple(20));
      final data =
          jsonDecode(
                jsonEncode(
                  ScorerDraftStorage.checkpoint(
                    original,
                    sessionId: 'match',
                    playedAt: DateTime(2026),
                  ),
                ),
              )
              as Map<String, dynamic>;
      final storage = ScorerDraftStorage();
      await storage.save('anna', data);
      expect(await storage.load('ben'), isNull);
      expect(await storage.load(null), isNull);
      final saved = (await storage.load('anna'))!;
      final restored = ScorerController(
        ScorerDraftStorage.decodeSettings(saved['settings']),
      );
      restored.restoreActions(saved['actions']);
      expect(restored.remaining, original.remaining);
      expect(restored.activePlayer, original.activePlayer);
      expect(restored.statisticsVisits.length, 2);
      expect(restored.visit.single.label, 'T20');
      restored.undo();
      expect(restored.remaining, 401);
      final again = ScorerController(settings)
        ..restoreActions(restored.exportActions());
      expect(again.remaining, 401);
      await storage.removeSession('anna', 'different');
      expect(await storage.load('anna'), isNotNull);
      await storage.removeSession('anna', 'match');
      expect(await storage.load('anna'), isNull);
      original.dispose();
      restored.dispose();
      again.dispose();
    },
  );

  for (final size in [
    const Size(360, 800),
    const Size(800, 600),
    const Size(1440, 900),
  ]) {
    testWidgets('Exit choice and saved session at $size with large text', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => ScorerMatchPage(settings: settings),
                  ),
                ),
                child: const Text('Start'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Start'));
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Spiel zwischenspeichern?'), findsOneWidget);
      await tester.tap(find.text('Weiterspielen'));
      await tester.pumpAndSettle();
      expect(find.byType(ScorerMatchPage), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Speichern und verlassen'));
      await tester.tap(find.text('Speichern und verlassen'));
      await tester.pumpAndSettle();
      expect(find.byType(ScorerMatchPage), findsNothing);
      expect(await ScorerDraftStorage().load(null), isNotNull);
      expect(tester.takeException(), isNull);
    });
  }
}
