import 'package:flutter_test/flutter_test.dart';
import 'package:dart_tournament_manager/features/tournaments/domain/tournament_format_planner.dart';
import 'package:dart_tournament_manager/features/tournaments/domain/tournament_planning_parameters.dart';

void main() {
  test('mandatory groups are a hard filter even for fallback suggestions', () {
    TournamentPlanningRequest request(bool required) => TournamentPlanningRequest(
      players: 2, boards: 1, minimumMatchesPerPlayer: 1,
      minimumMinutes: 1, maximumMinutes: 2, x01Selection: '501',
      checkoutType: 'double_out', maximumGroups: 1, requireGroupPhase: required,
    );
    expect(const TournamentFormatPlanner().suggestFormats(request(true)), isEmpty);
    final results = const TournamentFormatPlanner().suggestFormats(request(false));
    expect(results, isNotEmpty);
    expect(results.every((s) => s.stages.every((stage) => stage.type != 'groups')), isTrue);
  });
  test(
    'group requirement is independent of the cap and allows multiple stages',
    () {
      const planner = TournamentFormatPlanner();
      TournamentPlanningRequest request(bool required) =>
          TournamentPlanningRequest(
            players: 8,
            boards: 2,
            minimumMatchesPerPlayer: 1,
            minimumMinutes: 0,
            maximumMinutes: 10000,
            x01Selection: '501',
            checkoutType: 'double_out',
            maximumGroups: 2,
            requireGroupPhase: required,
          );
      final unrestricted = planner.suggest(request(false));
      final knockout = unrestricted.firstWhere(
        (s) => s.stages.first.type == 'single_knockout',
      );
      expect(knockout.totalMatches, 7);
      expect(knockout.matchBreakdown.total, 7);
      expect(knockout.duration!.groupSlots, 0);
      expect(knockout.duration!.knockoutSlots, 4);
      final required = planner.suggest(request(true));
      expect(required, isNotEmpty);
      expect(
        required.every((s) => s.stages.any((stage) => stage.type == 'groups')),
        isTrue,
      );
      expect(required.any((s) => s.stages.length > 1), isTrue);
      expect(
        required
            .expand((s) => s.stages)
            .where((s) => s.type == 'groups')
            .every((s) => s.groupCount <= 2),
        isTrue,
      );
    },
  );
  test('search group limit overrides settings without changing them', () {
    final planner = TournamentFormatPlanner(
      parameters: TournamentPlanningParameters.fromValues({
        PlanningParameter.maximumGroups: 4,
        PlanningParameter.maximumSuggestions: 64,
      }),
    );
    List<int> groups(int? limit) =>
        planner
            .suggest(
              TournamentPlanningRequest(
                players: 13,
                boards: 4,
                minimumMatchesPerPlayer: 0,
                minimumMinutes: 0,
                maximumMinutes: 10000,
                x01Selection: '501',
                checkoutType: 'double_out',
                maximumGroups: limit,
              ),
            )
            .map((s) => s.stages.first.groupCount)
            .toList()
          ..sort();
    expect(groups(1), [0, 1]);
    expect(groups(2), [0, 1, 2]);
    expect(groups(6), [0, 1, 2, 3, 4]);
    expect(groups(null), [0, 1, 2, 3, 4]);
    expect(groups(64).last, 4);
    expect(groups(0), isEmpty);
    expect(groups(65), isEmpty);
  });
}
