import 'package:flutter_test/flutter_test.dart';
import 'package:dart_tournament_manager/features/tournaments/domain/knockout_round_names.dart';
import 'package:dart_tournament_manager/features/tournaments/domain/tournament_models.dart';

void main() {
  test('last four rounds have consistent names, earlier rounds are numbered', () {
    expect(List.generate(6, (i) => knockoutRoundName(i, 6)), [
      'Runde 1', 'Runde 2', 'Achtelfinale', 'Viertelfinale', 'Halbfinale', 'Finale',
    ]);
  });
  test('loser and winner rounds are named independently of global round IDs', () {
    final matches = [
      GroupMatch(round: 1, label: 'Winners Runde 1'),
      GroupMatch(round: 2, label: 'Winners Runde 2'),
      GroupMatch(round: 3, label: 'Losers Runde 1'),
      GroupMatch(round: 4, label: 'Losers Runde 2'),
      GroupMatch(round: 5, label: 'Grand Final'),
      GroupMatch(round: 6, label: 'Grand Final Reset'),
    ];
    expect(matches.map((m) => knockoutMatchName(m, matches)), [
      'Halbfinale', 'Finale', 'Loser-Bracket · Halbfinale', 'Loser-Bracket · Finale', 'Finale', 'Finale',
    ]);
  });
  test('placement games and league rounds retain their own names', () {
    final placement = GroupMatch(round: 100, label: 'Spiel um Platz 3');
    expect(knockoutMatchName(placement, [placement]), 'Spiel um Platz 3');
    final group = GroupTournamentRunStage(name: 'Liga', groups: [], groupPlayType: 'round_robin', qualificationPlan: null, tieBreakers: []);
    expect(stageMatchName(group, GroupMatch(round: 2)), 'Runde 2');
  });
}
