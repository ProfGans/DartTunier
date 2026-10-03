import 'package:flutter_test/flutter_test.dart';
import 'package:dart_tournament_manager/features/tournaments/application/expanded_format_planner.dart';
import 'package:dart_tournament_manager/features/tournaments/domain/tournament_format_planner.dart';

void main() {
  for (final modes in <Set<String>>[
    {}, {'single_knockout'}, {'groups:round_robin', 'double_knockout'},
  ]) {
    test('each stage respects mode filter $modes', () async {
      final results = await const ExpandedFormatPlanner().suggest(
        TournamentPlanningRequest(players: 8, boards: 2,
          minimumMatchesPerPlayer: 0, minimumMinutes: 0, maximumMinutes: 100000,
          x01Selection: '301', checkoutType: 'double_out',
          maximumStages: 3, enabledModes: modes), allResults: true);
      if (modes.isEmpty) {
        expect(results, isEmpty);
      } else {
        expect(results, isNotEmpty);
        for (final suggestion in results) {
          for (final stage in suggestion.configurations) {
            expect(modes, contains(stage.type == 'groups'
              ? 'groups:${stage.groupPlayType}' : stage.type));
          }
        }
      }
    });
  }
}
