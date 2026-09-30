import '../data/generated_theo_lookup_table.dart';

// Adapted from the original app: same packed table, search and tie-breaking.
class TheoLookupResolution {
  const TheoLookupResolution({
    required this.skill,
    required this.finishingSkill,
    required this.theoreticalAverage,
  });

  final int skill;
  final int finishingSkill;
  final double theoreticalAverage;
}

class _TheoLookupCandidate {
  const _TheoLookupCandidate({
    required this.skill,
    required this.finishingSkill,
    required this.theoreticalAverage,
    required this.error,
  });

  final int skill;
  final int finishingSkill;
  final double theoreticalAverage;
  final double error;

  int get gap => (skill - finishingSkill).abs();

  TheoLookupResolution toResolution() {
    return TheoLookupResolution(
      skill: skill,
      finishingSkill: finishingSkill,
      theoreticalAverage: theoreticalAverage,
    );
  }
}

class TheoResolutionLookup {
  static const double minSupportedAverage = 35;
  static const double maxSupportedAverage = 120;
  static const int _minimumSkill = 1;
  static const int _maximumSkill = 1000;
  static bool usesSupportedGrid({
    required double targetAverage,
    required int effectiveRadiusCalibrationPercent,
    required int effectiveSimulationSpreadPercent,
    required int minSupportedEffectiveRadiusCalibrationPercent,
    required int maxSupportedEffectiveRadiusCalibrationPercent,
    required int fixedSupportedEffectiveSimulationSpreadPercent,
  }) {
    return targetAverage >= minSupportedAverage &&
        targetAverage <= maxSupportedAverage &&
        effectiveRadiusCalibrationPercent >=
            minSupportedEffectiveRadiusCalibrationPercent &&
        effectiveRadiusCalibrationPercent <=
            maxSupportedEffectiveRadiusCalibrationPercent &&
        effectiveSimulationSpreadPercent ==
            fixedSupportedEffectiveSimulationSpreadPercent;
  }

  static TheoLookupResolution resolve({
    required double targetAverage,
    required int effectiveRadiusCalibrationPercent,
    required int effectiveSimulationSpreadPercent,
    required int minSupportedEffectiveRadiusCalibrationPercent,
    required int maxSupportedEffectiveRadiusCalibrationPercent,
    required int fixedSupportedEffectiveSimulationSpreadPercent,
    required double Function(int skill, int finishingSkill) estimateAverage,
    Map<String, TheoLookupResolution>? cache,
    bool scheduleSupportedGridPrewarm = true,
  }) {
    final useSupportedGrid = usesSupportedGrid(
      targetAverage: targetAverage,
      effectiveRadiusCalibrationPercent: effectiveRadiusCalibrationPercent,
      effectiveSimulationSpreadPercent: effectiveSimulationSpreadPercent,
      minSupportedEffectiveRadiusCalibrationPercent:
          minSupportedEffectiveRadiusCalibrationPercent,
      maxSupportedEffectiveRadiusCalibrationPercent:
          maxSupportedEffectiveRadiusCalibrationPercent,
      fixedSupportedEffectiveSimulationSpreadPercent:
          fixedSupportedEffectiveSimulationSpreadPercent,
    );
    final normalizedTarget = useSupportedGrid
        ? normalizeSupportedAverage(targetAverage)
        : targetAverage.clamp(0, 180).toDouble();
    final cacheKey = <String>[
      'lookup',
      effectiveRadiusCalibrationPercent.toString(),
      effectiveSimulationSpreadPercent.toString(),
      useSupportedGrid
          ? normalizedTarget.toStringAsFixed(1)
          : normalizedTarget.toStringAsFixed(4),
    ].join('|');
    final cached = cache?[cacheKey];
    if (cached != null) {
      return cached;
    }

    final precomputed = useSupportedGrid
        ? resolvePrecomputed(
            targetAverage: normalizedTarget,
            effectiveRadiusCalibrationPercent:
                effectiveRadiusCalibrationPercent,
            effectiveSimulationSpreadPercent: effectiveSimulationSpreadPercent,
            minSupportedEffectiveRadiusCalibrationPercent:
                minSupportedEffectiveRadiusCalibrationPercent,
            maxSupportedEffectiveRadiusCalibrationPercent:
                maxSupportedEffectiveRadiusCalibrationPercent,
            fixedSupportedEffectiveSimulationSpreadPercent:
                fixedSupportedEffectiveSimulationSpreadPercent,
          )
        : null;
    if (precomputed != null) {
      cache?[cacheKey] = precomputed;
      return precomputed;
    }

    _TheoLookupCandidate buildCandidate({
      required int skill,
      required int finishingSkill,
    }) {
      final average = estimateAverage(skill, finishingSkill);
      return _TheoLookupCandidate(
        skill: skill,
        finishingSkill: finishingSkill,
        theoreticalAverage: average,
        error: (average - normalizedTarget).abs(),
      );
    }

    final bestEqual = _searchCandidate(
      target: normalizedTarget,
      minimumValue: _minimumSkill,
      maximumValue: _maximumSkill,
      buildValueCandidate: (value) =>
          buildCandidate(skill: value, finishingSkill: value),
    );
    final moveUp = normalizedTarget >= bestEqual.theoreticalAverage;
    final minimumValue = moveUp ? bestEqual.skill : _minimumSkill;
    final maximumValue = moveUp ? _maximumSkill : bestEqual.skill;
    final skillDriven = _searchCandidate(
      target: normalizedTarget,
      minimumValue: minimumValue,
      maximumValue: maximumValue,
      buildValueCandidate: (value) => buildCandidate(
        skill: value,
        finishingSkill: bestEqual.finishingSkill,
      ),
    );
    final finishingDriven = _searchCandidate(
      target: normalizedTarget,
      minimumValue: minimumValue,
      maximumValue: maximumValue,
      buildValueCandidate: (value) =>
          buildCandidate(skill: bestEqual.skill, finishingSkill: value),
    );

    const improvementEpsilon = 0.01;
    final bestSplit = _pickBetterCandidate(
      current: skillDriven,
      next: finishingDriven,
    );
    final resolution =
        bestSplit != null &&
            bestSplit.error + improvementEpsilon < bestEqual.error
        ? bestSplit.toResolution()
        : bestEqual.toResolution();
    cache?[cacheKey] = resolution;
    return resolution;
  }

  static TheoLookupResolution? resolvePrecomputed({
    required double targetAverage,
    required int effectiveRadiusCalibrationPercent,
    required int effectiveSimulationSpreadPercent,
    required int minSupportedEffectiveRadiusCalibrationPercent,
    required int maxSupportedEffectiveRadiusCalibrationPercent,
    required int fixedSupportedEffectiveSimulationSpreadPercent,
  }) {
    if (!usesSupportedGrid(
      targetAverage: targetAverage,
      effectiveRadiusCalibrationPercent: effectiveRadiusCalibrationPercent,
      effectiveSimulationSpreadPercent: effectiveSimulationSpreadPercent,
      minSupportedEffectiveRadiusCalibrationPercent:
          minSupportedEffectiveRadiusCalibrationPercent,
      maxSupportedEffectiveRadiusCalibrationPercent:
          maxSupportedEffectiveRadiusCalibrationPercent,
      fixedSupportedEffectiveSimulationSpreadPercent:
          fixedSupportedEffectiveSimulationSpreadPercent,
    )) {
      return null;
    }
    final packed = _packedBucketForRadius(
      effectiveRadiusCalibrationPercent,
      effectiveSimulationSpreadPercent,
    );
    if (packed == null || packed.isEmpty) {
      return null;
    }
    return _resolvePacked(
      packed: packed,
      normalizedTarget: normalizeSupportedAverage(targetAverage),
    );
  }

  static double normalizeSupportedAverage(double value) {
    final clamped = value.clamp(minSupportedAverage, maxSupportedAverage);
    return ((clamped * 10).round() / 10).toDouble();
  }

  static TheoLookupResolution? _resolvePacked({
    required List<int> packed,
    required double normalizedTarget,
  }) {
    final targetTenths = (normalizedTarget * 10).round();
    if (targetTenths < kTheoLookupAverageMinTenths ||
        targetTenths > kTheoLookupAverageMaxTenths) {
      return null;
    }
    final index = targetTenths - kTheoLookupAverageMinTenths;
    final dataIndex = index * 2;
    if (dataIndex < 0 || dataIndex + 1 >= packed.length) {
      return null;
    }
    return TheoLookupResolution(
      skill: packed[dataIndex],
      finishingSkill: packed[dataIndex + 1],
      theoreticalAverage: normalizedTarget,
    );
  }

  static List<int>? _packedBucketForRadius(
    int effectiveRadiusCalibrationPercent,
    int effectiveSimulationSpreadPercent,
  ) {
    if (effectiveSimulationSpreadPercent !=
        kTheoLookupSupportedEffectiveSpreadPercent) {
      return null;
    }
    final bundled =
        kTheoLookupSkillPairsByEffectiveRadius[effectiveRadiusCalibrationPercent];
    if (bundled != null && bundled.isNotEmpty) {
      return bundled;
    }
    return null;
  }

  static _TheoLookupCandidate _searchCandidate({
    required double target,
    required int minimumValue,
    required int maximumValue,
    required _TheoLookupCandidate Function(int value) buildValueCandidate,
  }) {
    var low = minimumValue;
    var high = maximumValue;
    _TheoLookupCandidate? best;

    while (low <= high) {
      final middle = (low + high) ~/ 2;
      final middleCandidate = buildValueCandidate(middle);
      best = _pickBetterCandidate(current: best, next: middleCandidate);
      if (middleCandidate.theoreticalAverage < target) {
        low = middle + 1;
      } else {
        high = middle - 1;
      }
    }

    for (final value in <int>{low, high, low - 1, high + 1}) {
      if (value < minimumValue || value > maximumValue) {
        continue;
      }
      best = _pickBetterCandidate(
        current: best,
        next: buildValueCandidate(value),
      );
    }

    return best!;
  }

  static _TheoLookupCandidate? _pickBetterCandidate({
    required _TheoLookupCandidate? current,
    required _TheoLookupCandidate next,
  }) {
    if (current == null) {
      return next;
    }
    const errorEpsilon = 0.0001;
    if (next.error + errorEpsilon < current.error) {
      return next;
    }
    if (current.error + errorEpsilon < next.error) {
      return current;
    }
    if (next.gap != current.gap) {
      return next.gap < current.gap ? next : current;
    }
    final nextMaxSkill = next.skill > next.finishingSkill
        ? next.skill
        : next.finishingSkill;
    final currentMaxSkill = current.skill > current.finishingSkill
        ? current.skill
        : current.finishingSkill;
    if (nextMaxSkill != currentMaxSkill) {
      return nextMaxSkill < currentMaxSkill ? next : current;
    }
    final nextMinSkill = next.skill < next.finishingSkill
        ? next.skill
        : next.finishingSkill;
    final currentMinSkill = current.skill < current.finishingSkill
        ? current.skill
        : current.finishingSkill;
    if (nextMinSkill != currentMinSkill) {
      return nextMinSkill < currentMinSkill ? next : current;
    }
    if (next.skill != current.skill) {
      return next.skill < current.skill ? next : current;
    }
    if (next.finishingSkill != current.finishingSkill) {
      return next.finishingSkill < current.finishingSkill ? next : current;
    }
    return current;
  }
}
