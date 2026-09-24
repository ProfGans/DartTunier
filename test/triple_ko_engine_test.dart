import 'dart:convert';
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_tournament_manager/features/tournaments/domain/tournament_models.dart';
import 'package:dart_tournament_manager/features/tournaments/modes/triple_ko/triple_ko_engine.dart';

List<List<GroupMatch>> bracket(int count) {
  var size = 2;
  while (size < count) {
    size *= 2;
  }
  final players = List.generate(
    count,
    (i) => TournamentPlayer(name: 'P$i', isGenerated: true),
  );
  return TripleKoEngine.build([
    for (var i = 0; i < size; i += 2)
      GroupMatch(
        round: 1,
        allowsBye: true,
        label: tripleRoundLabel(0, 1),
        homePlayer: i < count ? players[i] : null,
        awayPlayer: i + 1 < count ? players[i + 1] : null,
      ),
  ]);
}

String snapshot(List<List<GroupMatch>> rounds) => jsonEncode([
  for (final r in rounds) [for (final m in r) m.toJson()],
]);

void main() {
  test('three losses eliminate each non-champion, including final comebacks', () {
    for (var count = 2; count <= 17; count++) {
      for (var seed = 0; seed < 12; seed++) {
        var rounds = bracket(count);
        final random = Random(seed);
        var played = 0;
        while (true) {
          TripleKoEngine.advance(rounds);
          final before = snapshot(rounds);
          TripleKoEngine.advance(rounds);
          expect(
            snapshot(rounds),
            before,
            reason: 'progression must preserve results',
          );
          final ready = rounds
              .expand((r) => r)
              .where((m) => m.hasPlayers && !m.isResolved)
              .toList();
          if (ready.isEmpty) break;
          final m = ready[random.nextInt(ready.length)];
          expect(m.homePlayer!.name, isNot(m.awayPlayer!.name));
          m.homeLegs = random.nextBool() ? 2 : 1;
          m.awayLegs = 3 - m.homeLegs!;
          expect(++played, lessThanOrEqualTo(3 * (count - 1) + 2));
          // Persistence must not change progression or require player identity.
          rounds = [
            for (final r in rounds)
              [for (final m in r) GroupMatch.fromJson(m.toJson())],
          ];
        }
        final losses = <String, int>{for (var i = 0; i < count; i++) 'P$i': 0};
        for (final m in rounds.expand((r) => r)) {
          if (m.loser != null) {
            losses[m.loser!.name] = losses[m.loser!.name]! + 1;
          }
        }
        expect(
          losses.values.where((n) => n < 3).length,
          1,
          reason: '$count players, seed $seed',
        );
        expect(losses.values.where((n) => n == 3).length, count - 1);
        expect(rounds.last.single.winner, isNotNull);
      }
    }
  });

  test('clearing a source removes dependent results and board assignments', () {
    final rounds = bracket(5);
    for (var step = 0; step < 30; step++) {
      TripleKoEngine.advance(rounds);
      final ready = rounds
          .expand((r) => r)
          .where((m) => m.hasPlayers && !m.isResolved);
      if (ready.isEmpty) break;
      ready.first
        ..homeLegs = 2
        ..awayLegs = 1
        ..boardNumber = 1;
    }
    expect(rounds.last.single.hasResult, isTrue);
    rounds.first.first
      ..homeLegs = null
      ..awayLegs = null;
    TripleKoEngine.advance(rounds);
    expect(rounds.last.single.hasPlayers, isFalse);
    expect(rounds.last.single.hasResult, isFalse);
    expect(rounds.last.single.boardNumber, isNull);
    final before = snapshot(rounds);
    TripleKoEngine.advance(rounds, update: false);
    expect(
      snapshot(rounds),
      before,
      reason: 'drawing the bracket must be read-only',
    );
  });
}
