import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_tournament_manager/features/tournaments/application/tournament_bot_factory.dart';
import 'package:dart_tournament_manager/features/tournaments/application/tournament_bot_round_simulator.dart';
import 'package:dart_tournament_manager/features/tournaments/domain/tournament_models.dart';

void main() {
  test(
    'long 501 bot matches finish without statistics and yield for cancellation',
    () async {
      final bots = await TournamentBotFactory.create(
        count: 2,
        minimum: 60,
        maximum: 60,
        existingNames: [],
      );
      final games = List.generate(
        3,
        (_) => GroupMatch(homePlayer: bots[0], awayPlayer: bots[1], round: 1),
      );
      final simulator = TournamentBotRoundSimulator();
      expect(
        await simulator.run(
          matches: () => games,
          format: const TournamentGameFormat(x01Score: 501, bestOfLegs: 21),
          advance: () {},
          isActive: () => true,
          random: Random(42),
        ),
        3,
      );
      expect(
        games.every(
          (m) => m.hasResult && m.deviceResult?['statistics'] == null,
        ),
        true,
      );
      final cancelled = GroupMatch(
        homePlayer: bots[0],
        awayPlayer: bots[1],
        round: 1,
      );
      var active = true;
      final future = simulator.run(
        matches: () => [cancelled],
        format: const TournamentGameFormat(x01Score: 501, bestOfLegs: 101),
        advance: () {},
        isActive: () => active,
        random: Random(42),
      );
      await Future<void>.delayed(Duration.zero);
      active = false;
      expect(await future, 0);
      expect(cancelled.hasResult, false);
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
  test(
    'waits for humans, records statistics, advances and does not replay',
    () async {
      final bots = await TournamentBotFactory.create(
        count: 2,
        minimum: 70,
        maximum: 70,
        existingNames: [],
      );
      final botMatch = GroupMatch(
        homePlayer: bots[0],
        awayPlayer: bots[1],
        round: 1,
      );
      final humanMatch = GroupMatch(
        homePlayer: const TournamentPlayer(name: 'Mensch', isGenerated: false),
        awayPlayer: bots[0],
        round: 1,
      );
      final next = GroupMatch(
        homePlayer: bots[0],
        awayPlayer: bots[1],
        round: 2,
      );
      final matches = [botMatch, humanMatch];
      final simulator = TournamentBotRoundSimulator();
      var advances = 0;
      final savedCounts = <int>[];
      Future<int> run() => simulator.run(
        checkpoint: () async {
          savedCounts.add(matches.where((m) => m.hasResult).length);
        },
        matches: () => matches,
        format: const TournamentGameFormat(x01Score: 40, bestOfLegs: 1),
        advance: () {
          if (advances++ == 0) matches.add(next);
        },
        isActive: () => true,
        random: Random(7),
      );
      expect(await run(), 0);
      expect(botMatch.hasResult, false);
      humanMatch.homeLegs = 1;
      humanMatch.awayLegs = 0;
      expect(await run(), 2);
      expect(savedCounts, [2, 2, 3, 3]);
      expect(botMatch.deviceResult?['statistics'], isNull);
      expect(botMatch.startedAt, isNull);
      expect(GroupMatch.fromJson(botMatch.toJson()).hasResult, true);
      expect(await run(), 0);
    },
  );

  test(
    'unknown participants and externally started games are not simulated',
    () async {
      final bots = await TournamentBotFactory.create(
        count: 2,
        minimum: 70,
        maximum: 70,
        existingNames: [],
      );
      final match = GroupMatch(
        homePlayer: bots[0],
        awayPlayer: bots[1],
        round: 1,
      );
      final unknown = GroupMatch(round: 1);
      final matches = [match, unknown];
      final simulator = TournamentBotRoundSimulator();
      Future<int> run() => simulator.run(
        matches: () => matches,
        format: const TournamentGameFormat(x01Score: 40, bestOfLegs: 1),
        advance: () {},
        isActive: () => true,
      );
      expect(await run(), 0);
      matches.remove(unknown);
      match.startedAt = DateTime.now();
      expect(await run(), 0);
      expect(match.hasResult, false);
    },
  );
}
