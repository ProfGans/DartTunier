import 'package:flutter_test/flutter_test.dart';
import 'package:dart_tournament_manager/features/tournaments/domain/engines/group_bye_seeding.dart';
import 'package:dart_tournament_manager/features/tournaments/domain/tournament_models.dart';

void main() {
  test('complete ties use a stable lottery rather than alphabetical priority', () {
    final players = [for (final name in ['A', 'B', 'C'])
      TournamentPlayer(name: name, isGenerated: false)];
    final candidates = [for (var i = 0; i < players.length; i++)
      BestOfCandidate(groupName: '$i', groupNumber: i + 1, place: 1,
        standing: PlayerStanding(players[i])..played = 3..points = 9)];
    List<int?> draw(String key, List<BestOfCandidate> entries) => const GroupByeSeeding().assign(
      slots: [1, null, 2, 3], players: players, candidates: entries,
      tieBreakers: defaultGroupTieBreakers, drawKey: key);
    final recipients = <int?>{};
    for (var i = 0; i < 40; i++) {
      final result = draw('tournament-$i', candidates);
      expect(draw('tournament-$i', candidates.reversed.toList()), result);
      recipients.add(result.first);
    }
    expect(recipients, {1, 2, 3});
    expect(const GroupByeSeeding().compare(candidates[0], candidates[1], defaultGroupTieBreakers), 0);
  });
  test(
    'best group winners from B and C get byes instead of the first two in A',
    () {
      final players = [
        for (final name in ['A1', 'A2', 'B1', 'B2', 'C1', 'C2'])
          TournamentPlayer(name: name, isGenerated: false),
      ];
      final candidates = [
        for (var i = 0; i < players.length; i++)
          BestOfCandidate(
            groupName: '${i ~/ 2}',
            groupNumber: i ~/ 2 + 1,
            place: i % 2 + 1,
            standing: PlayerStanding(players[i])
              ..played = (i < 2 ? 4 : 3)
              ..points = (i == 0
                  ? 8
                  : i.isEven
                  ? 9
                  : 3)
              ..legsFor = 9
              ..legsAgainst = 3,
          ),
      ];
      final slots = const GroupByeSeeding().assign(
        slots: [1, null, 4, 5, 2, null, 3, 6],
        players: players,
        candidates: candidates,
        tieBreakers: ['points', 'legDifference', 'legsFor'],
      );
      expect({slots[0], slots[4]}, {3, 5});
      expect(slots.whereType<int>().toSet(), {1, 2, 3, 4, 5, 6});
      expect(slots.where((s) => s == null).length, 2);
      final again = const GroupByeSeeding().assign(
        slots: slots,
        players: players,
        candidates: candidates.reversed.toList(),
        tieBreakers: ['points', 'legDifference', 'legsFor'],
      );
      expect(again, slots);
    },
  );
  test('larger groups do not benefit from raw point totals', () {
    BestOfCandidate candidate(String name, int played, int points) =>
        BestOfCandidate(
          groupName: name,
          groupNumber: 1,
          place: 1,
          standing:
              PlayerStanding(TournamentPlayer(name: name, isGenerated: false))
                ..played = played
                ..points = points,
        );
    expect(
      const GroupByeSeeding().compare(
        candidate('A', 4, 10),
        candidate('B', 3, 9),
        ['points'],
      ),
      greaterThan(0),
    );
  });
}
