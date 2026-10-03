import 'package:flutter_test/flutter_test.dart';
import 'package:dart_tournament_manager/features/scorer/domain/scorer_statistics.dart';
import 'package:dart_tournament_manager/features/scorer/domain/scorer_highlight_rules.dart';

void main() {
  ScorerVisit visit(
    int points, {
    int leg = 0,
    bool finish = false,
    bool bust = false,
    int darts = 3,
  }) => ScorerVisit(
    player: 0,
    leg: leg,
    starter: 0,
    points: points,
    darts: darts,
    remaining: finish ? 0 : 100,
    bust: bust,
    checkoutAttempts: 0,
  );
  test('all requested maxima count exactly; busts and other scores do not', () {
    final stats = ScorerStatistics.calculate(
      [
        for (final points in highlightMaximumScores) visit(points),
        visit(177),
        visit(161),
        visit(179),
        visit(180, bust: true),
      ],
      playerCount: 2,
      startScores: [501, 501],
      standard501Rules: true,
    ).players.first;
    expect(stats.maxima, {
      162: 1,
      165: 1,
      168: 1,
      171: 1,
      174: 1,
      177: 2,
      180: 1,
    });
    expect(stats.shortLegs, isEmpty);
  });
  test(
    'finished 17 and 18 dart legs count; 19 darts and unfinished legs do not',
    () {
      final stats = ScorerStatistics.calculate(
        [
          for (var leg = 0; leg < 3; leg++) ...[
            for (var i = 0; i < (leg == 2 ? 6 : 5); i++) visit(60, leg: leg),
            visit(
              40,
              leg: leg,
              finish: true,
              darts: leg == 0
                  ? 2
                  : leg == 1
                  ? 3
                  : 1,
            ),
          ],
          visit(60, leg: 3),
        ],
        playerCount: 2,
        startScores: [501, 501],
        standard501Rules: true,
      ).players.first;
      expect(stats.shortLegs, {17: 1, 18: 1});
      expect(
        highlightCountLabel(stats.shortLegs, unit: ' Darts'),
        '1 × 17 Darts · 1 × 18 Darts',
      );
    },
  );
}
