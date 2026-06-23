part of 'main.dart';

const String _doubleWinnersPrefix = 'Winners Runde ';
const String _doubleLosersPrefix = 'Losers Runde ';
const String _doubleGrandFinalLabel = 'Grand Final';
const String _doubleResetFinalLabel = 'Reset Final';
const String _tripleFinalLabel = 'Triple-KO Finalrunde';

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

List<List<GroupMatch>> _buildDoubleEliminationRoundsFromSlots(
  List<TournamentPlayer> players,
  List<int?> slots,
) {
  if (players.length < 2 || slots.length < 2) {
    return const [];
  }

  final bracketSize = slots.length;
  final winnersRoundCount = _log2PowerOfTwo(bracketSize);
  final rounds = <List<GroupMatch>>[];

  final firstWinnersRound = <GroupMatch>[];
  for (var index = 0; index < bracketSize; index += 2) {
    final homeSeed = slots[index];
    final awaySeed = slots[index + 1];
    firstWinnersRound.add(
      GroupMatch(
        homePlayer: homeSeed == null ? null : players[homeSeed - 1],
        awayPlayer: awaySeed == null ? null : players[awaySeed - 1],
        round: 1,
        allowsBye: true,
        label: '${_doubleWinnersPrefix}1',
      ),
    );
  }
  rounds.add(firstWinnersRound);

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
        ),
    ];

    if (winnersRoundNumber == 2) {
      final initialLosersMatchCount = bracketSize >> 2;
      column.addAll([
        for (var index = 0; index < initialLosersMatchCount; index++)
          GroupMatch(
            round: rounds.length + 1,
            label: '$_doubleLosersPrefix${losersRoundNumber++}',
          ),
      ]);
    }

    rounds.add(column);

    rounds.add([
      for (var index = 0; index < winnersMatchCount; index++)
        GroupMatch(
          round: rounds.length + 1,
          label: '$_doubleLosersPrefix$losersRoundNumber',
        ),
    ]);
    losersRoundNumber++;

    if (winnersRoundNumber < winnersRoundCount) {
      rounds.add([
        for (var index = 0; index < (winnersMatchCount ~/ 2); index++)
          GroupMatch(
            round: rounds.length + 1,
            label: '$_doubleLosersPrefix$losersRoundNumber',
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

int _log2PowerOfTwo(int value) {
  var size = value;
  var exponent = 0;
  while (size > 1) {
    size ~/= 2;
    exponent++;
  }
  return exponent;
}

String _doubleWinnersLabel(int roundNumber) {
  return '$_doubleWinnersPrefix$roundNumber';
}

String _doubleLosersLabel(int roundNumber) {
  return '$_doubleLosersPrefix$roundNumber';
}

int? _doubleRoundNumber(String? label, String prefix) {
  if (label == null || !label.startsWith(prefix)) {
    return null;
  }
  return int.tryParse(label.substring(prefix.length));
}

List<GroupMatch> _matchesWithLabel(
  List<List<GroupMatch>> rounds,
  String label,
) {
  return [
    for (final round in rounds)
      for (final match in round)
        if (match.label == label) match,
  ];
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
