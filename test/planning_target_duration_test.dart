import 'package:flutter_test/flutter_test.dart';
import 'package:dart_tournament_manager/features/tournaments/domain/tournament_format_planner.dart';

void main() {
  const planner = TournamentFormatPlanner();
  TournamentPlanningRequest request(int? target, {int minimum = 1}) =>
      TournamentPlanningRequest(
        players: 12,
        boards: 3,
        minimumMatchesPerPlayer: minimum,
        minimumMinutes: 1,
        maximumMinutes: 2,
        targetMinutes: target,
        x01Selection: '501',
        checkoutType: 'double_out',
      );

  test('target replaces window and sorts by absolute distance', () {
    for (final target in [90, 180, 300]) {
      final results = planner.suggestFormats(request(target));
      expect(results, isNotEmpty);
      final distances = results
          .map((s) => (s.estimatedMinutes - target).abs())
          .toList();
      expect(distances, orderedEquals([...distances]..sort()));
      expect(results.every((s) => !s.isClosestAlternative), isTrue);
      expect(results.first.estimatedMinutes, greaterThan(2));
    }
  });

  test('target preserves minimum games when feasible', () {
    final results = planner.suggestFormats(request(180, minimum: 5));
    expect(results, isNotEmpty);
    expect(results.every((s) => s.minimumMatchesPerPlayer >= 5), isTrue);
  });

  test('window fallback is unchanged; invalid targets are rejected', () {
    expect(
      planner
          .suggestFormats(request(null))
          .every((s) => s.isClosestAlternative),
      isTrue,
    );
    expect(planner.suggestFormats(request(0)), isEmpty);
    expect(planner.suggestFormats(request(-1)), isEmpty);
  });
}
