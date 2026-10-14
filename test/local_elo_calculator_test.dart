import 'package:flutter_test/flutter_test.dart';
import 'package:dart_tournament_manager/features/rankings/domain/local_elo_calculator.dart';
import 'package:dart_tournament_manager/features/tournaments/domain/tournament_models.dart';

CreatedTournament tournament(
  String id,
  DateTime date,
  String home,
  String away, {
  bool assigned = true,
}) {
  final match = GroupMatch(
    round: 1,
    homePlayer: TournamentPlayer(profileId: home, name: home, isGenerated: false),
    awayPlayer: TournamentPlayer(profileId: away, name: away, isGenerated: false),
    homeLegs: 2,
    awayLegs: 0,
  );
  return CreatedTournament(
    id: id,
    name: id,
    createdAt: date,
    startedAt: date,
    players: [match.homePlayer!, match.awayPlayer!],
    stages: [],
    runStages: [KnockoutTournamentRunStage(name: 'Finale', rounds: [[match]])],
    rankingIds: assigned ? const ['season'] : const [],
  );
}

void main() {
  const calculator = LocalEloCalculator();

  test('only counts completed matches between assigned ranking players', () {
    final snapshot = calculator.calculate(
      players: const {'a': 'Anna', 'b': 'Ben'},
      tournaments: [
        tournament('ranked-match', DateTime.utc(2026, 2), 'a', 'b'),
        tournament('guest-match', DateTime.utc(2026, 3), 'a', 'guest'),
      ],
      rankingId: 'season',
      now: DateTime.utc(2026, 12),
    );

    expect(snapshot.entries.map((player) => player.id).toSet(), {'a', 'b'});
    expect(snapshot.entries.every((player) => player.matches == 1), isTrue);
    expect(snapshot.history['a'], hasLength(1));
    expect(snapshot.history['a']!.single.opponentName, 'Ben');
  });

  test('applies ranking assignment and date range before replay', () {
    final old = tournament('old', DateTime.utc(2025, 12), 'a', 'b');
    final unassigned = tournament(
      'other',
      DateTime.utc(2026, 2),
      'a',
      'b',
      assigned: false,
    );
    final snapshot = calculator.calculate(
      players: const {'a': 'Anna', 'b': 'Ben'},
      tournaments: [old, unassigned],
      rankingId: 'season',
      validFromYear: 2026,
      validToYear: 2026,
    );

    expect(snapshot.entries, isEmpty);
  });
}
