import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_tournament_manager/features/scorer/application/scorer_controller.dart';
import 'package:dart_tournament_manager/features/scorer/domain/scorer_settings.dart';
import 'package:dart_tournament_manager/features/scorer/domain/fixed_checkouts.dart';
import 'package:dart_tournament_manager/features/scorer/domain/x01/x01_models.dart';
import 'package:dart_tournament_manager/features/scorer/domain/x01/x01_rules.dart';
import 'package:dart_tournament_manager/features/scorer/domain/x01/x01_match_engine.dart';
import 'package:dart_tournament_manager/features/scorer/data/repositories/checkout_route_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const rules = X01Rules();
  ScorerController game({
    int score = 40,
    int legs = 1,
    int sets = 1,
    StartRequirement start = StartRequirement.straightIn,
  }) => ScorerController(
    ScorerSettings(
      startScore: score,
      bestOfLegs: legs,
      bestOfSets: sets,
      startRequirement: start,
      participants: const [ScorerParticipant('A'), ScorerParticipant('B')],
    ),
  );
  test('Best of is converted to required wins', () {
    final c = game(legs: 5, sets: 3);
    expect(c.settings.matchConfig.legsToWin, 3);
    expect(c.settings.matchConfig.setsToWin, 2);
    c.dispose();
  });
  test('Bust restores full visit; undo restores active dart', () {
    final c = game();
    c.throwDart(rules.createSingle(20));
    c.throwDart(rules.createSingle(19));
    expect(c.scores, [40, 40]);
    expect(c.activePlayer, 1);
    c.undo();
    expect(c.activePlayer, 0);
    expect(c.remaining, 20);
    expect(c.dartsLeft, 2);
    c.dispose();
  });
  test('Double In ignores singles and rolls back opening on bust', () {
    final c = game(start: StartRequirement.doubleIn);
    c.throwDart(rules.createSingle(20));
    expect(c.remaining, 40);
    c.throwDart(rules.createDouble(10));
    expect(c.remaining, 20);
    c.throwDart(rules.createTriple(20));
    expect(c.opened[0], false);
    expect(c.scores[0], 40);
    c.dispose();
  });
  test('Leg starts alternate, sets reset legs, undo reopens match', () {
    final c = game(sets: 3);
    c.throwDart(rules.createDouble(20));
    expect(c.sets, [1, 0]);
    expect(c.legs, [0, 0]);
    expect(c.activePlayer, 1);
    c.throwDart(rules.createDouble(20));
    expect(c.sets, [1, 1]);
    expect(c.activePlayer, 0);
    c.throwDart(rules.createDouble(20));
    expect(c.winner, 0);
    c.undo();
    expect(c.winner, null);
    expect(c.sets, [1, 1]);
    expect(c.remaining, 40);
    c.dispose();
  });
  test('Invalid best-of and bot-only matches are rejected', () {
    expect(() => game(legs: 2), throwsArgumentError);
    expect(() => ScorerSettings(participants: const []), throwsArgumentError);
  });
  test('Every fixed checkout is unique, legal and has at most five routes', () {
    final engine = X01MatchEngine();
    for (final requirement in CheckoutRequirement.values) {
      for (var darts = 1; darts <= 3; darts++) {
        for (var score = 1; score <= 180; score++) {
          final routes = FixedCheckouts.routes(
            score,
            dartsLeft: darts,
            requirement: requirement,
          );
          expect(routes.length, lessThanOrEqualTo(5));
          expect(
            routes.map((r) => r.map((d) => d.label).join(',')).toSet().length,
            routes.length,
          );
          for (final route in routes) {
            expect(route.length, lessThanOrEqualTo(darts));
            final result = engine.evaluateVisit(
              currentScore: score,
              throws: route,
              startRequirement: StartRequirement.straightIn,
              hasOpenedLeg: true,
              checkoutRequirement: requirement,
            );
            expect(result.didBust, false, reason: '$score $requirement');
            expect(result.remainingScore, 0);
          }
        }
      }
    }
    expect(FixedCheckouts.routes(170).length, 1);
    expect(FixedCheckouts.routes(169), isEmpty);
    expect(FixedCheckouts.routes(100).length, 5);
  });
  test('Bot uses imported assets and undo returns to human turn', () async {
    await CheckoutRouteRepository.instance.initialize();
    final c = ScorerController(
      ScorerSettings(
        participants: const [
          ScorerParticipant('A'),
          ScorerParticipant(
            'Bot',
            bot: BotProfile(skill: 500, finishingSkill: 500),
          ),
        ],
      ),
      random: Random(42),
    );
    for (var i = 0; i < 3; i++) {
      c.throwDart(rules.createTriple(20));
    }
    expect(c.isBotTurn, true);
    for (var i = 0; i < 3 && c.isBotTurn; i++) {
      c.playBotDart();
    }
    expect(c.isBotTurn, false);
    c.undo();
    expect(c.activePlayer, 0);
    expect(c.visit.length, 2);
    expect(c.remaining, 381);
    c.dispose();
  });
}
