import 'package:flutter_test/flutter_test.dart';

import 'package:dart_tournament_manager/features/tournaments/domain/tournament_format_planner.dart';

void main() {
  const planner = TournamentFormatPlanner();

  test('uses only boards that can actually be occupied in small groups', () {
    final suggestions = planner.suggest(
      const TournamentPlanningRequest(
        players: 7,
        boards: 4,
        minimumMatchesPerPlayer: 2,
        minimumMinutes: 0,
        maximumMinutes: 600,
        x01Selection: '501',
        checkoutType: 'double_out',
      ),
    );

    final twoGroups = suggestions.firstWhere(
      (suggestion) => suggestion.stages.first.groupCount == 2,
    );
    expect(twoGroups.effectiveBoards, lessThan(4));
  });

  test('honours duration and match minimum constraints', () {
    final suggestions = planner.suggest(
      const TournamentPlanningRequest(
        players: 8,
        boards: 2,
        minimumMatchesPerPlayer: 3,
        minimumMinutes: 120,
        maximumMinutes: 240,
        x01Selection: '501',
        checkoutType: 'double_out',
      ),
    );

    expect(suggestions, isNotEmpty);
    for (final suggestion in suggestions) {
      expect(suggestion.minimumMatchesPerPlayer, greaterThanOrEqualTo(3));
      expect(suggestion.estimatedMinutes, inInclusiveRange(120, 240));
    }
  });
}
