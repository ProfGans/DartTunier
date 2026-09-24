import 'package:flutter_test/flutter_test.dart';
import 'package:dart_tournament_manager/features/tournaments/application/order_of_play/order_of_play_controller.dart';
import 'package:dart_tournament_manager/features/tournaments/domain/tournament_models.dart';

CreatedTournament fixture({int boards = 2}) {
  final players = [for (var i = 1; i <= 6; i++) TournamentPlayer.generated(i)];
  return CreatedTournament(
    name: 'Test',
    players: players,
    stages: [],
    boardCount: boards,
    runStages: [
      GroupTournamentRunStage(
        name: 'Gruppen',
        groupPlayType: 'round_robin',
        qualificationPlan: null,
        tieBreakers: defaultGroupTieBreakers,
        groups: [
          TournamentGroup(
            name: 'A',
            playType: 'round_robin',
            players: players,
            matches: [
              for (var a = 0; a < players.length; a++)
                for (var b = a + 1; b < players.length; b++)
                  GroupMatch(
                    homePlayer: players[a],
                    awayPlayer: players[b],
                    round: 1,
                  ),
            ],
          ),
        ],
      ),
    ],
  );
}

void main() {
  const controller = OrderOfPlayController();
  test('all matches scheduled once with no board or player conflicts', () {
    for (final boards in [1, 2, 3, 4]) {
      final tournament = fixture(boards: boards);
      final schedule = controller.plan(tournament, 0);
      expect(schedule.planned.length, 15);
      expect(schedule.planned.map((e) => e.entry.match).toSet().length, 15);
      for (final block in schedule.planned.map((e) => e.block).toSet()) {
        final wave = schedule.planned.where((e) => e.block == block).toList();
        expect(wave.length, lessThanOrEqualTo(boards));
        expect(wave.map((e) => e.board).toSet().length, wave.length);
        expect(
          wave.expand((e) => e.entry.players).toSet().length,
          wave.length * 2,
        );
      }
    }
  });
  test(
    'starting a later match replans and prevents concurrent player/board use',
    () {
      final tournament = fixture();
      final original = controller.plan(tournament, 0);
      final pulled = original.planned.last.entry.match;
      expect(controller.start(tournament, 0, pulled, 1), isTrue);
      final updated = controller.plan(tournament, 0);
      expect(updated.running.single.match, same(pulled));
      final busy = updated.running.single.players;
      for (final next in updated.planned.where((e) => e.block == 0)) {
        expect(next.board, 2);
        expect(next.entry.players.intersection(busy), isEmpty);
      }
      expect(
        controller.start(tournament, 0, updated.planned.first.entry.match, 1),
        isFalse,
      );
      pulled.homeLegs = 2;
      pulled.awayLegs = 0;
      controller.resultRecorded(pulled);
      final after = controller.plan(tournament, 0);
      expect(after.running, isEmpty);
      expect(after.finished.single.match, same(pulled));
      expect(after.planned.length, 14);
      expect(after.planned.first.entry.players.intersection(busy), isEmpty);
    },
  );
  test(
    'future stages and unresolved pairings wait; metadata survives reload',
    () {
      final tournament = fixture();
      tournament.runStages.add(
        KnockoutTournamentRunStage(
          name: 'Finale',
          rounds: [
            [GroupMatch(round: 1)],
          ],
        ),
      );
      final match = controller.plan(tournament, 0).planned.first.entry.match;
      controller.start(tournament, 0, match, 2);
      final restored = CreatedTournament.fromJson(tournament.toJson());
      expect(restored.boardCount, 2);
      final schedule = controller.plan(restored, 0);
      expect(schedule.running.single.match.boardNumber, 2);
      expect(schedule.running.single.match.startedAt, isNotNull);
      expect(schedule.waiting.length, 1);
      final legacy = tournament.toJson()..remove('boardCount');
      expect(CreatedTournament.fromJson(legacy).boardCount, 1);
    },
  );
  test('removing a result releases stale scheduling metadata', () {
    final match = GroupMatch(
      round: 1,
      startedAt: DateTime.now(),
      finishedAt: DateTime.now(),
      boardNumber: 1,
    );
    controller.resultRecorded(match);
    expect(match.startedAt, isNull);
    expect(match.finishedAt, isNull);
    expect(match.boardNumber, isNull);
  });
}
