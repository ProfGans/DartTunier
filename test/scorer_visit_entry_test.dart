import 'dart:io';
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_tournament_manager/features/scorer/application/scorer_controller.dart';
import 'package:dart_tournament_manager/features/scorer/domain/scorer_settings.dart';
import 'package:dart_tournament_manager/features/scorer/domain/bot_settings.dart';
import 'package:dart_tournament_manager/features/scorer/data/bot_settings_storage.dart';
import 'package:dart_tournament_manager/features/scorer/domain/visit_score_entry.dart';
import 'package:dart_tournament_manager/features/scorer/domain/x01/x01_models.dart';
import 'package:dart_tournament_manager/features/scorer/domain/bot/bot_engine.dart';
import 'package:dart_tournament_manager/features/scorer/domain/x01/x01_rules.dart';

void main() {
  ScorerController game({
    int score = 501,
    bool bot = false,
    bool doubleIn = false,
  }) => ScorerController(
    ScorerSettings(
      startScore: score,
      bestOfLegs: 1,
      startRequirement: doubleIn
          ? StartRequirement.doubleIn
          : StartRequirement.straightIn,
      participants: [
        const ScorerParticipant('A'),
        ScorerParticipant('B', bot: bot ? const BotSettings().profile() : null),
      ],
    ),
    random: Random(1),
  );
  test(
    'Calculator score commits a full visit and undo removes ensuing bot darts',
    () {
      final c = game(bot: true);
      c.submitScore(100);
      expect(c.scores[0], 401);
      expect(c.isBotTurn, true);
      for (var n = 0; n < 3; n++) {
        c.playBotDart();
      }
      expect(c.isBotTurn, false);
      c.undo();
      expect(c.activePlayer, 0);
      expect(c.scores, [501, 501]);
      expect(c.visit, isEmpty);
      c.dispose();
    },
  );
  test('Impossible aggregate values do not mutate the match', () {
    final c = game();
    for (final n in [-1, 163, 169, 179, 181]) {
      expect(() => c.submitScore(n), throwsArgumentError);
    }
    expect(c.scores, [501, 501]);
    expect(c.canUndo, false);
    c.submitScore(0);
    expect(c.activePlayer, 1);
    c.dispose();
  });
  test('Bust preserves score and Double In state', () {
    final c = game(score: 40, doubleIn: true);
    c.submitScore(60);
    expect(c.scores[0], 40);
    expect(c.opened[0], false);
    c.undo();
    c.submitBust();
    expect(c.scores[0], 40);
    expect(c.activePlayer, 1);
    c.dispose();
  });
  test('Checkout validates exact darts and opening rule', () {
    expect(
      VisitScoreEntry.canFinish(170, 3, CheckoutRequirement.doubleOut),
      true,
    );
    expect(
      VisitScoreEntry.canFinish(170, 2, CheckoutRequirement.doubleOut),
      false,
    );
    expect(
      VisitScoreEntry.canFinish(
        170,
        3,
        CheckoutRequirement.doubleOut,
        doubleIn: true,
      ),
      false,
    );
    expect(
      VisitScoreEntry.canFinish(1, 1, CheckoutRequirement.singleOut),
      true,
    );
    final c = game(score: 40);
    expect(() => c.submitScore(40), throwsArgumentError);
    c.submitScore(40, checkoutDarts: 1);
    expect(c.winner, 0);
    c.undo();
    expect(c.winner, null);
    c.dispose();
  });
  test(
    'Double In rejects impossible opening sums and remembers valid opening',
    () {
      final c = game(doubleIn: true);
      expect(() => c.submitScore(1), throwsArgumentError);
      c.submitScore(40);
      expect(c.opened[0], true);
      expect(c.scores[0], 461);
      c.dispose();
    },
  );
  test(
    'Bot calibration matches original app and changes simulated scatter',
    () {
      final defaults = const BotSettings().profile();
      expect(defaults.radiusCalibrationPercent, 86);
      expect(defaults.simulationSpreadPercent, 115);
      final engine = BotEngine();
      final target = const X01Rules().createTriple(20);
      final tight = engine.simulateTargetThrow(
        target: target,
        score: 501,
        profile: const BotSettings(
          radiusPercent: 50,
          spreadPercent: 70,
        ).profile(),
        random: Random(42),
      );
      final wide = engine.simulateTargetThrow(
        target: target,
        score: 501,
        profile: const BotSettings(
          radiusPercent: 150,
          spreadPercent: 140,
        ).profile(),
        random: Random(42),
      );
      expect(wide.scatterRadius, greaterThan(tight.scatterRadius));
    },
  );
  test(
    'Versioned bot settings persist, normalize and reject future schema',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'scorer_settings_test_',
      );
      addTearDown(() => directory.delete(recursive: true));
      final storage = BotSettingsStorage(
        file: File('${directory.path}/bots.json'),
      );
      expect((await storage.load()).skill, 500);
      const value = BotSettings(
        skill: 765,
        finishingSkill: 432,
        radiusPercent: 110,
        spreadPercent: 90,
        speedIndex: 2,
      );
      await storage.save(value);
      expect((await storage.load()).toJson(), value.toJson());
      await storage.save(const BotSettings());
      expect((await storage.load()).skill, 500);
      expect(
        BotSettings.fromJson({'schemaVersion': 1, 'skill': 9999}).skill,
        1000,
      );
      expect(
        () => BotSettings.fromJson({'schemaVersion': 3}),
        throwsFormatException,
      );
    },
  );
}
