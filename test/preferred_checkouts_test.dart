import 'package:flutter_test/flutter_test.dart';
import 'package:dart_tournament_manager/features/scorer/domain/preferred_checkouts.dart';
import 'package:dart_tournament_manager/features/scorer/domain/fixed_checkouts.dart';
import 'package:dart_tournament_manager/features/scorer/domain/x01/x01_models.dart';

void main() {
  String labels(List<DartThrowResult> route) =>
      route.map((d) => d.label).join('/');
  test('favorite adds a legal route, retaining standard alternatives', () {
    final routes = PreferredCheckouts.routes(40, favoriteDouble: 'D16');
    expect(labels(routes.first), '8/D16');
    expect(
      routes.map(labels),
      contains(labels(FixedCheckouts.routes(40).first)),
    );
    expect(
      PreferredCheckouts.routes(100, favoriteDouble: 'D20').first.last.label,
      'D20',
    );
    expect(
      labels(PreferredCheckouts.routes(50, favoriteDouble: 'Bull').first),
      'BULL',
    );
  });
  test('unreachable or invalid preference leaves suggestions unchanged', () {
    for (final favorite in ['', 'invalid', 'D0', 'D21', 'D20']) {
      expect(
        PreferredCheckouts.routes(
          32,
          dartsLeft: 1,
          favoriteDouble: favorite,
        ).map(labels),
        FixedCheckouts.routes(32, dartsLeft: 1).map(labels),
      );
    }
    expect(PreferredCheckouts.normalizeDouble(' d 16 '), 'D16');
    expect(PreferredCheckouts.normalizeDouble('16'), 'D16');
    expect(PreferredCheckouts.normalizeDouble('D25'), 'BULL');
  });
  test('personalized routes remain legal for all scores and out rules', () {
    for (final requirement in CheckoutRequirement.values) {
      for (var darts = 1; darts <= 3; darts++) {
        for (var score = 1; score <= 180; score++) {
          for (final favorite in ['D1', 'D16', 'D20', 'Bull']) {
            final routes = PreferredCheckouts.routes(
              score,
              dartsLeft: darts,
              requirement: requirement,
              favoriteDouble: favorite,
            );
            expect(routes.length, lessThanOrEqualTo(5));
            expect(routes.map(labels).toSet().length, routes.length);
            for (final route in routes) {
              expect(route.length, lessThanOrEqualTo(darts));
              expect(
                route.fold<int>(0, (sum, d) => sum + d.scoredPoints),
                score,
              );
              expect(
                route.last.matchesCheckoutRequirement(requirement),
                isTrue,
              );
            }
          }
        }
      }
    }
  });
}
