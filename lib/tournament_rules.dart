part of 'main.dart';

bool _isKnockoutStageType(String type) {
  return type == 'single_knockout' ||
      type == 'double_knockout' ||
      type == 'triple_knockout';
}

int _lossLimitForStageType(String type) {
  return switch (type) {
    'double_knockout' => 2,
    'triple_knockout' => 3,
    _ => 1,
  };
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

