import 'package:dart_tournament_manager/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('round robin engine creates repeated pairings', () {
    final players = List.generate(4, TournamentPlayer.generated);

    final matches = tournamentEngine.buildRoundRobinMatches(
      players,
      repeatCount: 2,
    );

    expect(matches, hasLength(12));
    expect(tournamentEngine.roundRobinMatchCount(4, 2), 12);
    expect(matches.first.homePlayer, players[0]);
    expect(matches.first.awayPlayer, players[3]);
  });

  test('engine estimates knockout and elimination sizes', () {
    expect(tournamentEngine.knockoutPlayableMatchCount(8), 7);
    expect(tournamentEngine.eliminationMatchEstimate(8, 2), 14);
    expect(tournamentEngine.nextPowerOfTwo(9), 16);
    expect(tournamentEngine.seedOrderForSize(4), [1, 4, 2, 3]);
  });
}
