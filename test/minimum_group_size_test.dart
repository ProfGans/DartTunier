import 'package:flutter_test/flutter_test.dart';
import 'package:dart_tournament_manager/features/dev_tools/domain/random_tournament_simulations.dart';
import 'package:dart_tournament_manager/features/dev_tools/domain/tournament_simulation_engine.dart';
import 'package:dart_tournament_manager/features/tournaments/domain/tournament_format_planner.dart';
import 'package:dart_tournament_manager/features/tournaments/domain/group_size_rules.dart';

void main() {
  test('random groups have at least three players including seed 103', () {
    for (var seed = 0; seed < 1000; seed++) {
      for (final stage in randomTournamentScenario(seed).stages.whereType<SimulationGroupStageSpec>()) {
        expect(hasValidGroupSizes(stage.groupSizes), isTrue, reason: 'Seed $seed');
      }
    }
  });
  test('finder excludes undersized groups even in fallback suggestions', () {
    for (var players = 2; players <= 16; players++) {
      final suggestions = const TournamentFormatPlanner().suggestFormats(TournamentPlanningRequest(
        players: players, boards: 4, minimumMatchesPerPlayer: 0, minimumMinutes: 0,
        maximumMinutes: 1, maximumGroups: 64, x01Selection: '501', checkoutType: 'double_out'));
      if (players < 3) { expect(suggestions, isEmpty); }
      else { expect(suggestions, isNotEmpty); }
      for (final s in suggestions) { expect(hasValidGroupSizes(s.matchBreakdown.groupSizes), isTrue); }
    }
    expect(hasValidGroupSizes([3, 2]), isFalse);
    expect(hasValidGroupSizes([3, 3]), isTrue);
    expect(hasValidGroupSizes([]), isFalse);
  });
}
