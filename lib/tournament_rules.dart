part of 'main.dart';

const List<String> defaultGroupTieBreakers = [
  'points',
  'legDifference',
  'legsFor',
  'headToHead',
];

String tieBreakerLabel(String tieBreaker) {
  return switch (tieBreaker) {
    'points' => 'Punkte',
    'legDifference' => 'Leg-Differenz',
    'legsFor' => 'Gewonnene Legs',
    'headToHead' => 'Direkter Vergleich',
    _ => tieBreaker,
  };
}

String groupLabel(int groupNumber) {
  var number = groupNumber;
  var label = '';
  while (number > 0) {
    number--;
    label = String.fromCharCode(65 + (number % 26)) + label;
    number ~/= 26;
  }

  return 'Gruppe $label';
}

int _roundRobinRepeatForStage(TournamentStage stage, int groupIndex) {
  if (groupIndex < 0 || groupIndex >= stage.groupRoundRobinRepeats.length) {
    return 1;
  }

  final repeatCount = stage.groupRoundRobinRepeats[groupIndex];
  return repeatCount < 1 ? 1 : repeatCount;
}

String _groupPlayTypeForStage(TournamentStage stage, int groupIndex) {
  if (groupIndex >= 0 && groupIndex < stage.groupPlayTypes.length) {
    return stage.groupPlayTypes[groupIndex];
  }

  return stage.groupPlayType;
}

String _groupPlayTypeLabel(String playType) {
  return switch (playType) {
    'round_robin' => 'Jeder gegen jeden',
    'mini_knockout' => 'Mini-KO in der Gruppe',
    'double_knockout' => 'Doppel-KO in der Gruppe',
    'triple_knockout' => 'Triple-KO in der Gruppe',
    _ => playType,
  };
}

bool _isKnockoutStageType(String type) {
  return type == 'single_knockout' ||
      type == 'double_knockout' ||
      type == 'triple_knockout';
}

bool _isEliminationGroupPlayType(String playType) {
  return playType == 'mini_knockout' ||
      playType == 'double_knockout' ||
      playType == 'triple_knockout';
}

int _lossLimitForStageType(String type) {
  return switch (type) {
    'double_knockout' => 2,
    'triple_knockout' => 3,
    _ => 1,
  };
}

int _lossLimitForGroupPlayType(String playType) {
  return switch (playType) {
    'double_knockout' => 2,
    'triple_knockout' => 3,
    _ => 1,
  };
}

List<GroupMatch> _buildRoundRobinMatches(
  List<TournamentPlayer> players, {
  int repeatCount = 1,
}) {
  final matches = <GroupMatch>[];
  if (players.length < 2) {
    return matches;
  }

  final playerCount = players.length.isOdd
      ? players.length + 1
      : players.length;
  final rounds = playerCount - 1;
  final matchesPerRound = playerCount ~/ 2;
  final safeRepeatCount = repeatCount < 1 ? 1 : repeatCount;

  for (var repeat = 0; repeat < safeRepeatCount; repeat++) {
    final rotation = List<TournamentPlayer?>.from(players);
    if (rotation.length.isOdd) {
      rotation.add(null);
    }

    for (var round = 0; round < rounds; round++) {
      for (var pairIndex = 0; pairIndex < matchesPerRound; pairIndex++) {
        final firstPlayer = rotation[pairIndex];
        final secondPlayer = rotation[playerCount - 1 - pairIndex];
        if (firstPlayer == null || secondPlayer == null) {
          continue;
        }

        final swapHome = repeat.isOdd;
        final homePlayer = swapHome ? secondPlayer : firstPlayer;
        final awayPlayer = swapHome ? firstPlayer : secondPlayer;

        matches.add(
          GroupMatch(
            homePlayer: homePlayer,
            awayPlayer: awayPlayer,
            round: repeat * rounds + round + 1,
          ),
        );
      }

      final fixedPlayer = rotation.first;
      final rotatingPlayers = rotation.sublist(1);
      rotatingPlayers.insert(0, rotatingPlayers.removeLast());
      rotation
        ..clear()
        ..add(fixedPlayer)
        ..addAll(rotatingPlayers);
    }
  }

  return matches;
}

int _roundRobinMatchCount(int groupSize, int repeatCount) {
  if (groupSize < 2) {
    return 0;
  }

  final safeRepeatCount = repeatCount < 1 ? 1 : repeatCount;
  return (groupSize * (groupSize - 1) ~/ 2) * safeRepeatCount;
}

int _knockoutPlayableMatchCount(int participantCount) {
  return participantCount < 2 ? 0 : participantCount - 1;
}

int _eliminationMatchEstimate(int participantCount, int lossLimit) {
  if (participantCount < 2) {
    return 0;
  }

  final safeLossLimit = lossLimit < 1 ? 1 : lossLimit;
  return safeLossLimit == 1
      ? _knockoutPlayableMatchCount(participantCount)
      : participantCount * safeLossLimit - safeLossLimit;
}

int _nextPowerOfTwo(int value) {
  var size = 2;
  while (size < value) {
    size *= 2;
  }
  return size;
}

List<int> _seedOrderForSize(int bracketSize) {
  var order = <int>[1, 2];
  var size = 2;
  while (size < bracketSize) {
    final nextSize = size * 2;
    order = [
      for (final seed in order) ...[seed, nextSize + 1 - seed],
    ];
    size = nextSize;
  }

  return order;
}

class _KnockoutSeedSource {
  const _KnockoutSeedSource({
    required this.seed,
    required this.groupNumber,
    required this.place,
  });

  final int seed;
  final int? groupNumber;
  final int place;
}

