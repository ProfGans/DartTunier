import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_tournament_manager/features/tournaments/application/tournament_bot_factory.dart';
import 'package:dart_tournament_manager/features/tournaments/application/tournament_bot_round_simulator.dart';
import 'package:dart_tournament_manager/features/tournaments/domain/tournament_models.dart';

void main() {
  test('waits for humans, records statistics, advances and does not replay', () async {
    final bots = await TournamentBotFactory.create(count: 2, minimum: 70,
      maximum: 70, existingNames: []);
    final botMatch = GroupMatch(homePlayer: bots[0], awayPlayer: bots[1], round: 1);
    final humanMatch = GroupMatch(homePlayer: const TournamentPlayer(name: 'Mensch', isGenerated: false),
      awayPlayer: bots[0], round: 1);
    final next = GroupMatch(homePlayer: bots[0], awayPlayer: bots[1], round: 2);
    final matches = [botMatch, humanMatch];
    final simulator = TournamentBotRoundSimulator();
    var advances = 0;
    Future<int> run() => simulator.run(matches: () => matches,
      format: const TournamentGameFormat(x01Score: 40, bestOfLegs: 1),
      advance: () { if (advances++ == 0) matches.add(next); },
      isActive: () => true, random: Random(7));
    expect(await run(), 0);
    expect(botMatch.hasResult, false);
    humanMatch.homeLegs = 1;
    humanMatch.awayLegs = 0;
    expect(await run(), 2);
    expect(botMatch.deviceResult?['statistics'], isNull);
    expect(botMatch.startedAt, isNull);
    expect(GroupMatch.fromJson(botMatch.toJson()).hasResult, true);
    expect(await run(), 0);
  });

  test('unknown participants and externally started games are not simulated', () async {
    final bots = await TournamentBotFactory.create(count: 2, minimum: 70,
      maximum: 70, existingNames: []);
    final match = GroupMatch(homePlayer: bots[0], awayPlayer: bots[1], round: 1);
    final unknown = GroupMatch(round: 1);
    final matches = [match, unknown];
    final simulator = TournamentBotRoundSimulator();
    Future<int> run() => simulator.run(matches: () => matches,
      format: const TournamentGameFormat(x01Score: 40, bestOfLegs: 1),
      advance: () {}, isActive: () => true);
    expect(await run(), 0);
    matches.remove(unknown);
    match.startedAt = DateTime.now();
    expect(await run(), 0);
    expect(match.hasResult, false);
  });
}
