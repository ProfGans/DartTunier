part of 'main.dart';

const String _doubleWinnersPrefix = 'Winners Runde ';
const String _doubleLosersPrefix = 'Losers Runde ';
const String _doubleGrandFinalLabel = 'Grand Final';
const String _doubleResetFinalLabel = 'Reset Final';

List<List<GroupMatch>> _buildDoubleEliminationRoundsFromSlots(
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
        label: hasBye ? _autoAdvanceLabel : '${_doubleWinnersPrefix}1',
      ),
    );
  }

  return _buildDoubleEliminationRoundsFromInitialRound(
    firstWinnersRound,
    bracketSize,
  );
}

List<List<GroupMatch>> _buildDoubleEliminationRoundsFromFirstRound(
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
            : '${_doubleWinnersPrefix}1',
        isAnnulled: match.isAnnulled,
      ),
  ];

  return _buildDoubleEliminationRoundsFromInitialRound(
    firstWinnersRound,
    firstWinnersRound.length * 2,
  );
}

List<List<GroupMatch>> _buildDoubleEliminationRoundsFromInitialRound(
  List<GroupMatch> firstWinnersRound,
  int bracketSize,
) {
  final winnersRoundCount = _log2PowerOfTwo(bracketSize);
  final rounds = <List<GroupMatch>>[firstWinnersRound];
  var losersRoundNumber = 1;
  for (var winnersRoundNumber = 2;
      winnersRoundNumber <= winnersRoundCount;
      winnersRoundNumber++) {
    final winnersMatchCount = bracketSize >> winnersRoundNumber;
    final column = <GroupMatch>[
      for (var index = 0; index < winnersMatchCount; index++)
        GroupMatch(
          round: rounds.length + 1,
          label: '$_doubleWinnersPrefix$winnersRoundNumber',
          allowsBye: true,
        ),
    ];

    if (winnersRoundNumber == 2) {
      final initialLosersMatchCount = bracketSize >> 2;
      column.addAll([
        for (var index = 0; index < initialLosersMatchCount; index++)
          GroupMatch(
            round: rounds.length + 1,
            label: '$_doubleLosersPrefix$losersRoundNumber',
            allowsBye: true,
          ),
      ]);
      losersRoundNumber++;
    }

    rounds.add(column);

    rounds.add([
      for (var index = 0; index < winnersMatchCount; index++)
        GroupMatch(
          round: rounds.length + 1,
          label: '$_doubleLosersPrefix$losersRoundNumber',
          allowsBye: true,
        ),
    ]);
    losersRoundNumber++;

    if (winnersRoundNumber < winnersRoundCount) {
      rounds.add([
        for (var index = 0; index < (winnersMatchCount ~/ 2); index++)
          GroupMatch(
            round: rounds.length + 1,
            label: '$_doubleLosersPrefix$losersRoundNumber',
            allowsBye: true,
          ),
      ]);
      losersRoundNumber++;
    }
  }

  rounds.add([
    GroupMatch(round: rounds.length + 1, label: _doubleGrandFinalLabel),
  ]);
  return rounds;
}

bool _doubleEliminationRoundsNeedRepair(List<List<GroupMatch>> rounds) {
  if (rounds.isEmpty || rounds.first.isEmpty) {
    return false;
  }

  final bracketSize = rounds.first.length * 2;
  final winnersRoundCount = _log2PowerOfTwo(bracketSize);
  if (_doubleWinnersRoundCount(rounds) != winnersRoundCount) {
    return true;
  }

  final expectedLosersCounts = _doubleExpectedLosersMatchCounts(bracketSize);
  if (_doubleLosersRoundCount(rounds) != expectedLosersCounts.length) {
    return true;
  }

  for (final round in rounds) {
    for (final match in round) {
      final label = match.label;
      if (label != null &&
          (label.startsWith(_doubleLosersPrefix) ||
              (label.startsWith(_doubleWinnersPrefix) &&
                  label != _doubleWinnersLabel(1))) &&
          !match.allowsBye) {
        return true;
      }
    }
  }

  for (var roundNumber = 2; roundNumber <= winnersRoundCount; roundNumber++) {
    final expectedCount = bracketSize >> roundNumber;
    if (_matchesWithLabel(rounds, _doubleWinnersLabel(roundNumber)).length !=
        expectedCount) {
      return true;
    }
  }

  for (var index = 0; index < expectedLosersCounts.length; index++) {
    if (_matchesWithLabel(rounds, _doubleLosersLabel(index + 1)).length !=
        expectedLosersCounts[index]) {
      return true;
    }
  }

  return false;
}

List<int> _doubleExpectedLosersMatchCounts(int bracketSize) {
  final winnersRoundCount = _log2PowerOfTwo(bracketSize);
  final counts = <int>[];
  for (var winnersRoundNumber = 2;
      winnersRoundNumber <= winnersRoundCount;
      winnersRoundNumber++) {
    final winnersMatchCount = bracketSize >> winnersRoundNumber;
    if (winnersRoundNumber == 2) {
      counts.add(bracketSize >> 2);
    }
    counts.add(winnersMatchCount);
    if (winnersRoundNumber < winnersRoundCount) {
      counts.add(winnersMatchCount ~/ 2);
    }
  }
  return counts;
}

String _doubleWinnersLabel(int roundNumber) {
  return '$_doubleWinnersPrefix$roundNumber';
}

String _doubleLosersLabel(int roundNumber) {
  return '$_doubleLosersPrefix$roundNumber';
}

List<GroupMatch> _doubleWinnersRoundMatches(
  List<List<GroupMatch>> rounds,
  int roundNumber, {
  bool includeAutoAdvances = false,
}) {
  if (roundNumber == 1 && includeAutoAdvances && rounds.isNotEmpty) {
    return rounds.first;
  }

  return _matchesWithLabel(rounds, _doubleWinnersLabel(roundNumber));
}

int? _doubleRoundNumber(String? label, String prefix) {
  if (label == null || !label.startsWith(prefix)) {
    return null;
  }
  return int.tryParse(label.substring(prefix.length));
}

int _doubleWinnersRoundCount(List<List<GroupMatch>> rounds) {
  var highest = 0;
  for (final round in rounds) {
    for (final match in round) {
      final number = _doubleRoundNumber(match.label, _doubleWinnersPrefix);
      if (number != null && number > highest) {
        highest = number;
      }
    }
  }
  return highest;
}

int _doubleLosersRoundCount(List<List<GroupMatch>> rounds) {
  var highest = 0;
  for (final round in rounds) {
    for (final match in round) {
      final number = _doubleRoundNumber(match.label, _doubleLosersPrefix);
      if (number != null && number > highest) {
        highest = number;
      }
    }
  }
  return highest;
}
