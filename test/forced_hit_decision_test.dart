import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_tournament_manager/features/autoscoring/domain/board_geometry.dart';
import 'package:dart_tournament_manager/features/autoscoring/domain/forced_hit_decision.dart';

void main() {
  test('Single shaft resolves its remaining dimension from image changes', () {
    final hit = forceHitDecision(
      [DartAxis(const Point(0, -150), const Point(0, -50))],
      [
        [const Point(0, -80)],
        [const Point(0, -82)],
      ],
    );
    expect(hit.forcedDecision, isTrue);
    expect(hit.point.distanceTo(const Point(0, -81)), lessThan(2));
    expect(BoardGeometry.score(hit.point).label, '20');
  });
  test('Parallel shafts yield a bounded provisional score', () {
    final hit = forceHitDecision(
      [
        DartAxis(const Point(-1, -150), const Point(-1, -50)),
        DartAxis(const Point(1, -150), const Point(1, -50)),
      ],
      [
        [const Point(0, -80)],
        [const Point(0, -80)],
      ],
    );
    expect(hit.point.distanceTo(const Point(0, -80)), lessThan(2));
    expect(hit.forcedDecision, isTrue);
  });
  test('Motion evidence without shafts can decide an outer-rim miss', () {
    final hit = forceHitDecision([], [
      [const Point(0, -200)],
      [const Point(0, -200)],
    ]);
    expect(BoardGeometry.score(hit.point).scoredPoints, 0);
    expect(hit.point.distanceTo(const Point(0, -200)), lessThan(2));
    expect(hit.forcedDecision, isTrue);
  });
}
