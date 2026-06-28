part of '../../../../tournament_workspace.dart';

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

int _eliminationMatchEstimate(int participantCount, int lossLimit) {
  return tournamentEngine.eliminationMatchEstimate(participantCount, lossLimit);
}

int _nextPowerOfTwo(int value) {
  return tournamentEngine.nextPowerOfTwo(value);
}

List<int> _seedOrderForSize(int bracketSize) {
  return tournamentEngine.seedOrderForSize(bracketSize);
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

