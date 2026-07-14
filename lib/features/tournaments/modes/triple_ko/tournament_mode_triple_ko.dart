part of '../../../../tournament_workspace.dart';

const String _tripleFinalLabel = 'Triple-KO Finalrunde';

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
  return '${_lossLevelBracketTitle(lossCount)} Runde $roundNumber';
}

List<List<GroupMatch>> _buildTripleEliminationRoundsFromSlots(
  List<TournamentPlayer> players,
  List<int?> slots,
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

  return _buildTripleEliminationRoundsFromInitialRound(
    firstWinnersRound,
    bracketSize,
  );
}

List<List<GroupMatch>> _buildTripleEliminationRoundsFromFirstRound(
  List<GroupMatch> firstRound,
) {
  if (firstRound.isEmpty) {
    return const [];
  }

  final firstWinnersRound = [
    for (final match in firstRound)
      GroupMatch(
        homePlayer: match.homePlayer,
        awayPlayer: match.awayPlayer,
        round: 1,
        homeLegs: match.homeLegs,
        awayLegs: match.awayLegs,
        allowsBye: true,
        label: match.homePlayer == null || match.awayPlayer == null
            ? _autoAdvanceLabel
            : _lossLevelMatchLabel(0, 1),
        isAnnulled: match.isAnnulled,
      ),
  ];

  return _buildTripleEliminationRoundsFromInitialRound(
    firstWinnersRound,
    firstWinnersRound.length * 2,
  );
}

List<List<GroupMatch>> _buildTripleEliminationRoundsFromInitialRound(
  List<GroupMatch> firstWinnersRound,
  int bracketSize,
) {
  final rounds = <List<GroupMatch>>[firstWinnersRound];
  final winnersRoundCount = _log2PowerOfTwo(bracketSize);

  for (var roundNumber = 2; roundNumber <= winnersRoundCount; roundNumber++) {
    final matchCount = bracketSize >> roundNumber;
    rounds.add([
      for (var index = 0; index < matchCount; index++)
        GroupMatch(
          round: rounds.length + 1,
          label: _lossLevelMatchLabel(0, roundNumber),
          allowsBye: true,
        ),
    ]);
  }

  final lowerCounts = _doubleExpectedLosersMatchCounts(bracketSize);
  for (var lossCount = 1; lossCount <= 2; lossCount++) {
    for (var index = 0; index < lowerCounts.length; index++) {
      rounds.add([
        for (var matchIndex = 0; matchIndex < lowerCounts[index]; matchIndex++)
          GroupMatch(
            round: rounds.length + 1,
            label: _lossLevelMatchLabel(lossCount, index + 1),
            allowsBye: true,
          ),
      ]);
    }
  }

  rounds.add([
    GroupMatch(round: rounds.length + 1, label: _tripleFinalLabel),
  ]);
  return rounds;
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
