part of '../../../../tournament_workspace.dart';

const String _tripleFinalLabel = tripleFinalLabel;

String _lossLevelBracketLabel(int lossCount) {
  return switch (lossCount) {
    0 => 'Winners Bracket',
    1 => '1 Niederlage Bracket',
    _ => '$lossCount Niederlagen Bracket',
  };
}

String _lossLevelBracketTitle(int lossCount) {
  return switch (lossCount) {
    0 => '0 Niederlagen',
    1 => '1 Niederlage',
    _ => '$lossCount Niederlagen',
  };
}

String _lossLevelMatchLabel(int lossCount, int roundNumber) {
  return tripleRoundLabel(lossCount, roundNumber);
}

List<List<GroupMatch>> _buildTripleEliminationRoundsFromSlots(
  List<TournamentPlayer> players,
  List<int?> slots, {int lossLimit = 3}
) {
  if (players.length < 2 || slots.length < 2) {
    return const [];
  }

  final bracketSize = slots.length;
  final firstWinnersRound = <GroupMatch>[];
  for (var index = 0; index < bracketSize; index += 2) {
    final homeSeed = slots[index];
    final awaySeed = slots[index + 1];
    final hasBye = homeSeed == null || awaySeed == null;
    firstWinnersRound.add(
      GroupMatch(
        homePlayer: homeSeed == null ? null : players[homeSeed - 1],
        awayPlayer: awaySeed == null ? null : players[awaySeed - 1],
        round: 1,
        allowsBye: true,
        label: hasBye ? _autoAdvanceLabel : _lossLevelMatchLabel(0, 1),
      ),
    );
  }

  return TripleKoEngine.build(firstWinnersRound, lossLimit: lossLimit);
}

int _lossLevelRoundCount(List<List<GroupMatch>> rounds, int lossCount) {
  var highest = 0;
  for (final round in rounds) {
    for (final match in round) {
      final label = match.label;
      if (label == null) {
        continue;
      }
      final prefix = '${_lossLevelBracketTitle(lossCount)} Runde ';
      if (!label.startsWith(prefix)) {
        continue;
      }
      final number = int.tryParse(label.substring(prefix.length));
      if (number != null && number > highest) {
        highest = number;
      }
    }
  }
  return highest;
}
