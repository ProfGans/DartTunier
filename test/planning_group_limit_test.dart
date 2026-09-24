import 'package:flutter_test/flutter_test.dart';
import 'package:dart_tournament_manager/features/tournaments/domain/tournament_format_planner.dart';
import 'package:dart_tournament_manager/features/tournaments/domain/tournament_planning_parameters.dart';

void main() {
  test('search group limit overrides settings without changing them', () {
    final planner = TournamentFormatPlanner(parameters: TournamentPlanningParameters.fromValues({
      PlanningParameter.maximumGroups: 4, PlanningParameter.maximumSuggestions: 64,
    }));
    List<int> groups(int? limit) => planner.suggest(TournamentPlanningRequest(
      players: 13, boards: 4, minimumMatchesPerPlayer: 0,
      minimumMinutes: 0, maximumMinutes: 10000, x01Selection: '501',
      checkoutType: 'double_out', maximumGroups: limit,
    )).map((s) => s.stages.first.groupCount).toList()..sort();
    expect(groups(1), [1]);
    expect(groups(2), [1, 2]);
    expect(groups(6), [1, 2, 3, 4]);
    expect(groups(null), [1, 2, 3, 4]);
    expect(groups(64).last, 4);
    expect(groups(0), isEmpty);
    expect(groups(65), isEmpty);
  });
}
