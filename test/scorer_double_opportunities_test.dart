import 'package:flutter_test/flutter_test.dart';
import 'package:dart_tournament_manager/features/scorer/domain/visit_score_entry.dart';
import 'package:dart_tournament_manager/features/scorer/application/scorer_controller.dart';
import 'package:dart_tournament_manager/features/scorer/domain/scorer_settings.dart';

void main() {
  test('Actual total must allow reaching a double before the last dart', () {
    for (final example in [
      (170, 26, 0),
      (100, 26, 0),
      (100, 60, 2),
      (170, 120, 1),
      (170, 119, 0),
      (169, 129, 0),
      (40, 0, 3),
      (50, 0, 3),
      (501, 180, 0),
    ]) {
      expect(
        VisitScoreEntry.maxDoubleAttempts(
          score: example.$1,
          points: example.$2,
        ),
        example.$3,
        reason: '${example.$1} minus ${example.$2}',
      );
    }
    expect(
      VisitScoreEntry.maxDoubleAttempts(score: 40, points: 0, opened: false),
      0,
    );
    expect(VisitScoreEntry.maxDoubleAttempts(score: 170, points: 170), 1);
  });
  test('Impossible attempts become zero instead of unknown', () {
    final c = ScorerController(
      ScorerSettings(
        startScore: 170,
        participants: const [ScorerParticipant('A'), ScorerParticipant('B')],
      ),
    );
    c.submitScore(26);
    expect(c.statisticsVisits.single.checkoutAttempts, 0);
    c.dispose();
  });
}
