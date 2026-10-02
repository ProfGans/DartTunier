import 'package:flutter_test/flutter_test.dart';
import 'package:dart_tournament_manager/features/autoscoring/application/autoscore_demo_controller.dart';
import 'package:dart_tournament_manager/features/scorer/domain/x01/x01_rules.dart';

void main() {
  const rules = X01Rules();
  test(
    'Removing darts automatically accepts uncorrected throws and keeps corrections wrong',
    () {
      final c = AutoscoreDemoController();
      addTearDown(c.dispose);
      for (var i = 0; i < 6; i++) {
        c.add(rules.createTriple(20));
      }
      c.review(0, rules.createSingle(20));
      c.reset();
      expect(c.reviewedCount, 6);
      expect(c.correctCount, 5);
      expect(c.accuracyPercent, closeTo(100 * 5 / 6, .0001));
      expect(c.totalPoints, 0);
      c.reset();
      expect(c.reviewedCount, 6);
      c.confirm(0);
      expect(c.correctCount, 5);
    },
  );
  test(
    'Accuracy uses checked original detections and reviews are idempotent',
    () {
      final controller = AutoscoreDemoController();
      addTearDown(controller.dispose);
      controller.add(rules.createTriple(20));
      controller.add(rules.createDouble(20));
      controller.add(rules.createSingle(5));
      expect(controller.accuracyPercent, isNull);
      controller.confirm(0);
      controller.review(1, rules.createSingle(20));
      expect(controller.totalPoints, 85);
      expect(controller.reviewedCount, 2);
      expect(controller.accuracyPercent, 50);
      controller.review(1, rules.createSingle(20));
      expect(controller.reviewedCount, 2);
      controller.review(1, rules.createDouble(20));
      expect(controller.accuracyPercent, 50);
      expect(controller.totalPoints, 105);
    },
  );
  test(
    'Clearing a visit preserves accuracy and old reviews do not alter new points',
    () {
      final controller = AutoscoreDemoController();
      addTearDown(controller.dispose);
      controller.add(rules.createTriple(20));
      controller.confirm(0);
      controller.reset();
      expect(controller.totalPoints, 0);
      expect(controller.throws, isEmpty);
      expect(controller.accuracyPercent, 100);
      controller.add(rules.createBull());
      controller.review(0, rules.createDouble(20));
      expect(controller.totalPoints, 50);
      expect(controller.accuracyPercent, 0);
      controller.confirm(1);
      expect(controller.accuracyPercent, 50);
    },
  );
  test('Equal points in different segments are not a correct detection', () {
    final controller = AutoscoreDemoController();
    addTearDown(controller.dispose);
    controller.add(rules.createDouble(10));
    controller.review(0, rules.createSingle(20));
    expect(controller.totalPoints, 20);
    expect(controller.accuracyPercent, 0);
  });
}
