import 'package:flutter_test/flutter_test.dart';
import 'package:dart_tournament_manager/features/tournaments/domain/planning_format_progression.dart';
import 'package:dart_tournament_manager/features/tournaments/domain/tournament_models.dart';
import 'package:dart_tournament_manager/features/tournaments/domain/tournament_format_planner.dart';

void main() {
  test('later legs stay equal or increase by one best-of step', () {
    for (final legs in [1, 3, 5, 99]) {
      final previous = TournamentGameFormat(bestOfLegs: legs);
      expect(isPlanningFormatProgressionAllowed(previous, previous), isTrue);
      expect(isPlanningFormatProgressionAllowed(previous, TournamentGameFormat(bestOfLegs: legs + 2)), isTrue);
      expect(isPlanningFormatProgressionAllowed(previous, TournamentGameFormat(bestOfLegs: legs + 4)), isFalse);
      if (legs > 1) expect(isPlanningFormatProgressionAllowed(previous, TournamentGameFormat(bestOfLegs: legs - 2)), isFalse);
    }
    expect(isPlanningFormatProgressionAllowed(const TournamentGameFormat(bestOfLegs: 4), const TournamentGameFormat(bestOfLegs: 5)), isTrue);
    expect(isPlanningFormatProgressionAllowed(const TournamentGameFormat(bestOfLegs: 4), const TournamentGameFormat(bestOfLegs: 7)), isFalse);
    expect(isPlanningFormatProgressionAllowed(const TournamentGameFormat(bestOfSets: 1), const TournamentGameFormat(bestOfSets: 5)), isFalse);
    expect(isPlanningFormatProgressionAllowed(const TournamentGameFormat(bestOfSets: 3), const TournamentGameFormat(bestOfSets: 5)), isTrue);
  });
  test('all suggestions including fallback alternatives obey the cap', () {
    for (final maximum in [1, 240, 600]) {
      for (final sets in [false, true]) {
        final suggestions = const TournamentFormatPlanner().suggestFormats(TournamentPlanningRequest(
          players: 13, boards: 4, minimumMatchesPerPlayer: 3, minimumMinutes: 0, maximumMinutes: maximum,
          x01Selection: 'variable_301_501', checkoutType: 'double_out', allowSets: sets, allowDraws: true));
        expect(suggestions, isNotEmpty);
        for (final s in suggestions) {
          for (var i = 1; i < s.stages.length; i++) {
            expect(isPlanningFormatProgressionAllowed(s.stages[i-1].format, s.stages[i].format), isTrue);
          }
        }
      }
    }
  });
}
