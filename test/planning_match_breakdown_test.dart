import 'package:flutter_test/flutter_test.dart';
import 'package:dart_tournament_manager/features/tournaments/domain/tournament_format_planner.dart';
import 'package:dart_tournament_manager/features/tournaments/domain/tournament_planning_parameters.dart';

void main() {
  test(
    '13 players: counts stay identical with two or four boards; byes are excluded',
    () {
      final planner = TournamentFormatPlanner(
        parameters: TournamentPlanningParameters.fromValues({
          PlanningParameter.maximumSuggestions: 4,
        }),
      );
      List<TournamentFormatSuggestion> calculate(int boards) => planner.suggest(
        TournamentPlanningRequest(
          players: 13,
          boards: boards,
          minimumMatchesPerPlayer: 0,
          minimumMinutes: 0,
          maximumMinutes: 10000,
          x01Selection: '501',
          checkoutType: 'double_out',
        ),
      );
      final two = calculate(2);
      final four = calculate(4);
      for (final suggestion in two) {
        final matching = four.singleWhere(
          (other) =>
              other.stages.first.groupCount ==
              suggestion.stages.first.groupCount,
        );
        expect(matching.totalMatches, suggestion.totalMatches);
        expect(suggestion.totalMatches, suggestion.matchBreakdown.total);
      }
      final single = two.singleWhere((s) => s.stages.first.groupCount == 1);
      expect(single.totalMatches, 78);
      final groups2 = two.singleWhere((s) => s.stages.first.groupCount == 2);
      expect(groups2.matchBreakdown.groupMatches, [21, 15]);
      expect(groups2.matchBreakdown.knockoutMatches, 3);
      expect(groups2.totalMatches, 39);
      final groups3 = two.singleWhere((s) => s.stages.first.groupCount == 3);
      expect(groups3.matchBreakdown.groupMatches, [10, 6, 6]);
      expect(groups3.matchBreakdown.knockoutParticipants, 6);
      expect(groups3.matchBreakdown.byes, 2);
      expect(groups3.matchBreakdown.knockoutMatches, 5);
      expect(groups3.totalMatches, 27);
    },
  );
}
