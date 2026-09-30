import 'dart:math';

import '../../data/repositories/checkout_route_repository.dart';

import '../board/board_geometry.dart';
import '../fixed_checkouts.dart';
import '../x01/checkout_planner.dart';
import '../x01/x01_models.dart';
import '../x01/x01_rules.dart';

class BotAimDecision {
  const BotAimDecision({
    required this.target,
    required this.reason,
    this.route = const <DartThrowResult>[],
  });

  final DartThrowResult target;
  final String reason;
  final List<DartThrowResult> route;
}

class BotThrowSimulation {
  const BotThrowSimulation({
    required this.target,
    required this.hit,
    required this.targetPoint,
    required this.hitPoint,
    required this.scatterRadius,
    required this.reason,
    this.plannedRoute = const <DartThrowResult>[],
  });

  final DartThrowResult target;
  final DartThrowResult hit;
  final BoardPoint targetPoint;
  final BoardPoint hitPoint;
  final double scatterRadius;
  final String reason;
  final List<DartThrowResult> plannedRoute;
}

class _LeaveCandidate {
  const _LeaveCandidate({
    required this.target,
    required this.rest,
    required this.leavePreference,
  });

  final DartThrowResult target;
  final int rest;
  final int leavePreference;
}

class _ThrowModel {
  const _ThrowModel({
    required this.radialScale,
    required this.tangentialScale,
    required this.radialBias,
    required this.consistencySigma,
    required this.pressureMultiplier,
  });

  final double radialScale;
  final double tangentialScale;
  final double radialBias;
  final double consistencySigma;
  final double pressureMultiplier;
}

class _BotPerfTotals {
  int throwCount = 0;
  int totalMicroseconds = 0;
  int decideAimMicroseconds = 0;
  int aimPointMicroseconds = 0;
  int scatterPrepMicroseconds = 0;
  int throwModelMicroseconds = 0;
  int randomMicroseconds = 0;
  int projectMicroseconds = 0;
  int classifyMicroseconds = 0;

  void reset() {
    throwCount = 0;
    totalMicroseconds = 0;
    decideAimMicroseconds = 0;
    aimPointMicroseconds = 0;
    scatterPrepMicroseconds = 0;
    throwModelMicroseconds = 0;
    randomMicroseconds = 0;
    projectMicroseconds = 0;
    classifyMicroseconds = 0;
  }

  void record({
    required int totalMicrosecondsValue,
    required int decideAimMicrosecondsValue,
    required int aimPointMicrosecondsValue,
    required int scatterPrepMicrosecondsValue,
    required int throwModelMicrosecondsValue,
    required int randomMicrosecondsValue,
    required int projectMicrosecondsValue,
    required int classifyMicrosecondsValue,
  }) {
    throwCount += 1;
    totalMicroseconds += totalMicrosecondsValue;
    decideAimMicroseconds += decideAimMicrosecondsValue;
    aimPointMicroseconds += aimPointMicrosecondsValue;
    scatterPrepMicroseconds += scatterPrepMicrosecondsValue;
    throwModelMicroseconds += throwModelMicrosecondsValue;
    randomMicroseconds += randomMicrosecondsValue;
    projectMicroseconds += projectMicrosecondsValue;
    classifyMicroseconds += classifyMicrosecondsValue;
  }
}

class BotEngine {
  static const int _legacyRadiusBaselinePercent = 92;
  static const int _legacySimulationSpreadBaselinePercent = 115;

  BotEngine({
    X01Rules? rules,
    BoardGeometry? boardGeometry,
    CheckoutPlanner? checkoutPlanner,
    this.recordPerformanceLogs = false,
    this.onPerformanceLog,
  }) : rules = rules ?? const X01Rules(),
       boardGeometry = boardGeometry ?? const BoardGeometry(),
       checkoutPlanner =
           checkoutPlanner ?? CheckoutPlanner(rules: rules ?? const X01Rules());

  final X01Rules rules;
  final BoardGeometry boardGeometry;
  final CheckoutPlanner checkoutPlanner;
  final bool recordPerformanceLogs;
  final void Function(String source, String message)? onPerformanceLog;

  final Map<String, List<DartThrowResult>?> _preferredCheckoutCache =
      <String, List<DartThrowResult>?>{};
  final Map<String, DartThrowResult?> _preferredSetupTargetCache =
      <String, DartThrowResult?>{};
  final Map<String, DartThrowResult?> _inVisitSetupTargetCache =
      <String, DartThrowResult?>{};
  final Map<String, List<DartThrowResult>?> _preferredSetupRouteCache =
      <String, List<DartThrowResult>?>{};
  final Map<String, List<DartThrowResult>?> _preferredHighScoreSetupRouteCache =
      <String, List<DartThrowResult>?>{};
  final Map<String, DartThrowResult?> _preferredLeaveTargetCache =
      <String, DartThrowResult?>{};
  final Map<String, int> _leavePreferenceCache = <String, int>{};
  final Map<String, int> _leaveBullPenaltyCache = <String, int>{};
  final Map<String, List<List<DartThrowResult>>> _checkoutRoutesCache =
      <String, List<List<DartThrowResult>>>{};
  final Map<String, double> _theoreticalAverageCache = <String, double>{};
  final Map<String, BoardPoint> _aimPointCache = <String, BoardPoint>{};
  final Map<String, _ThrowModel> _throwModelCache = <String, _ThrowModel>{};
  final Map<String, BotAimDecision> _aimDecisionCache =
      <String, BotAimDecision>{};
  final List<DartThrowResult> _allThrows = const X01Rules().buildAllThrows();
  final _BotPerfTotals _perfTotals = _BotPerfTotals();

  Map<String, Object?> exportDeterministicTables() {
    return <String, Object?>{
      'version': 1,
      'preferredLeaveTargets': <String, Object?>{
        for (final entry in _preferredLeaveTargetCache.entries)
          entry.key.toString(): _serializeThrowLabel(entry.value),
      },
      'preferredCheckouts': <String, Object?>{
        for (final entry in _preferredCheckoutCache.entries)
          entry.key: _serializeRoute(entry.value),
      },
      'preferredSetupRoutes': <String, Object?>{
        for (final entry in _preferredSetupRouteCache.entries)
          entry.key: _serializeRoute(entry.value),
      },
      'preferredHighScoreSetupRoutes': <String, Object?>{
        for (final entry in _preferredHighScoreSetupRouteCache.entries)
          entry.key: _serializeRoute(entry.value),
      },
      'preferredSetupTargets': <String, Object?>{
        for (final entry in _preferredSetupTargetCache.entries)
          entry.key: _serializeThrowLabel(entry.value),
      },
      'inVisitSetupTargets': <String, Object?>{
        for (final entry in _inVisitSetupTargetCache.entries)
          entry.key: _serializeThrowLabel(entry.value),
      },
    };
  }

  void importDeterministicTables(Map<String, Object?> json) {
    final leaveTargets =
        ((json['preferredLeaveTargets'] as Map?) ?? const <Object?, Object?>{})
            .cast<Object?, Object?>();
    for (final entry in leaveTargets.entries) {
      _preferredLeaveTargetCache[entry.key.toString()] = _deserializeThrowLabel(
        entry.value,
      );
    }

    void importRouteMap(
      Map<String, List<DartThrowResult>?> target,
      Object? raw,
    ) {
      final routeMap = ((raw as Map?) ?? const <Object?, Object?>{})
          .cast<Object?, Object?>();
      for (final entry in routeMap.entries) {
        target[entry.key.toString()] = _deserializeRoute(entry.value);
      }
    }

    importRouteMap(_preferredCheckoutCache, json['preferredCheckouts']);
    importRouteMap(_preferredSetupRouteCache, json['preferredSetupRoutes']);
    importRouteMap(
      _preferredHighScoreSetupRouteCache,
      json['preferredHighScoreSetupRoutes'],
    );

    void importThrowMap(Map<String, DartThrowResult?> target, Object? raw) {
      final throwMap = ((raw as Map?) ?? const <Object?, Object?>{})
          .cast<Object?, Object?>();
      for (final entry in throwMap.entries) {
        target[entry.key.toString()] = _deserializeThrowLabel(entry.value);
      }
    }

    importThrowMap(_preferredSetupTargetCache, json['preferredSetupTargets']);
    importThrowMap(_inVisitSetupTargetCache, json['inVisitSetupTargets']);
  }

  void compactSimulationCaches() {
    _throwModelCache.clear();
    _checkoutRoutesCache.clear();
    checkoutPlanner.clearCaches();
  }

  void resetPerformanceTotals() {
    _perfTotals.reset();
  }

  Object? _serializeThrowLabel(DartThrowResult? entry) => entry?.label;

  List<Object?>? _serializeRoute(List<DartThrowResult>? route) {
    if (route == null) {
      return null;
    }
    return route.map((entry) => entry.label).toList(growable: false);
  }

  DartThrowResult? _deserializeThrowLabel(Object? value) {
    final label = value?.toString();
    if (label == null || label.isEmpty) {
      return null;
    }
    for (final entry in _allThrows) {
      if (entry.label == label) {
        return entry;
      }
    }
    return null;
  }

  List<DartThrowResult>? _deserializeRoute(Object? value) {
    if (value == null) {
      return null;
    }
    if (value is! List) {
      return null;
    }
    final route = <DartThrowResult>[];
    for (final label in value) {
      final entry = _deserializeThrowLabel(label);
      if (entry == null) {
        return null;
      }
      route.add(entry);
    }
    return route;
  }

  BotAimDecision decideAim({
    required BotProfile profile,
    required int score,
    required int dartsRemaining,
    CheckoutRequirement checkoutRequirement = CheckoutRequirement.doubleOut,
    CheckoutPlayStyle playStyle = CheckoutPlayStyle.balanced,
  }) {
    final cacheKey = <Object>[
      score,
      dartsRemaining,
      checkoutRequirement.name,
      playStyle.name,
      score == 50 && profile.finishingSkill >= 350 ? 1 : 0,
    ].join('|');
    final cached = _aimDecisionCache[cacheKey];
    if (cached != null) {
      return cached;
    }

    if (score == 50 && checkoutRequirement != CheckoutRequirement.singleOut) {
      final target = profile.finishingSkill >= 350
          ? rules.createBull()
          : rules.createOuterBull();
      final decision = BotAimDecision(
        target: target,
        reason: 'Bull finish decision',
      );
      _aimDecisionCache[cacheKey] = decision;
      return decision;
    }

    if (checkoutRequirement == CheckoutRequirement.doubleOut &&
        score <= 40 &&
        score.isEven) {
      final decision = BotAimDecision(
        target: rules.createDouble(score ~/ 2),
        reason: 'Direct double finish',
      );
      _aimDecisionCache[cacheKey] = decision;
      return decision;
    }

    if (dartsRemaining == 1 && score > 40) {
      final leaveTarget =
          findPreferredLeaveTarget(
            score,
            checkoutRequirement: checkoutRequirement,
            playStyle: playStyle,
          ) ??
          rules.createSingle((score - 2).clamp(0, 20));
      final decision = BotAimDecision(
        target: leaveTarget,
        reason: 'Preferred leave',
      );
      _aimDecisionCache[cacheKey] = decision;
      return decision;
    }

    if (score > 170) {
      if (score >= 350 && dartsRemaining == 3) {
        final highScoreSetup = findPreferredHighScoreSetupRoute(
          score: score,
          dartsLeft: dartsRemaining,
          checkoutRequirement: checkoutRequirement,
          playStyle: playStyle,
        );
        if (highScoreSetup != null && highScoreSetup.isNotEmpty) {
          final decision = BotAimDecision(
            target: highScoreSetup.first,
            reason: 'Preferred high-score setup',
            route: highScoreSetup,
          );
          _aimDecisionCache[cacheKey] = decision;
          return decision;
        }
      }

      final continuation =
          CheckoutRouteRepository.instance.bestContinuationPlan(
            score: score,
            dartsLeft: dartsRemaining,
            checkoutRequirement: checkoutRequirement,
            playStyle: playStyle,
          ) ??
          checkoutPlanner.bestContinuationPlan(
            score: score,
            dartsLeft: dartsRemaining,
            checkoutRequirement: checkoutRequirement,
            playStyle: playStyle,
            outerBullPreference: 50,
            bullPreference: 50,
          );
      if (continuation != null && continuation.throws.isNotEmpty) {
        final decision = BotAimDecision(
          target: continuation.throws.first,
          reason: 'Preferred continuation',
          route: continuation.throws,
        );
        _aimDecisionCache[cacheKey] = decision;
        return decision;
      }

      final decision = BotAimDecision(
        target: rules.createTriple(20),
        reason: 'Maximum scoring',
      );
      _aimDecisionCache[cacheKey] = decision;
      return decision;
    }

    final preferredCheckout = findPreferredCheckout(
      score: score,
      dartsLeft: dartsRemaining,
      checkoutRequirement: checkoutRequirement,
      playStyle: playStyle,
    );
    if (preferredCheckout != null && preferredCheckout.isNotEmpty) {
      final decision = BotAimDecision(
        target: preferredCheckout.first,
        reason: 'Preferred checkout',
        route: preferredCheckout,
      );
      _aimDecisionCache[cacheKey] = decision;
      return decision;
    }

    if (score <= 20) {
      final decision = BotAimDecision(
        target: rules.createSingle((score - 1).clamp(0, 20)),
        reason: 'Avoid bogey finish',
      );
      _aimDecisionCache[cacheKey] = decision;
      return decision;
    }

    final setupRoute = findPreferredSetupRoute(
      score: score,
      dartsLeft: dartsRemaining,
      checkoutRequirement: checkoutRequirement,
      playStyle: playStyle,
    );
    if (setupRoute != null && setupRoute.isNotEmpty) {
      final decision = BotAimDecision(
        target: setupRoute.first,
        reason: 'Preferred setup',
        route: setupRoute,
      );
      _aimDecisionCache[cacheKey] = decision;
      return decision;
    }

    final decision = BotAimDecision(
      target:
          findPreferredLeaveTarget(
            score,
            checkoutRequirement: checkoutRequirement,
            playStyle: playStyle,
          ) ??
          rules.createSingle((score - 2).clamp(0, 20)),
      reason: 'Default leave choice',
    );
    _aimDecisionCache[cacheKey] = decision;
    return decision;
  }

  double getCheckoutCommitChance(BotProfile profile) {
    final normalized = profile.finishingSkill.clamp(1, 1000) / 1000;
    final value = 0.2 + normalized * 0.78;
    return value > 0.995 ? 0.995 : value;
  }

  double getRadiusCalibrationFactor(BotProfile profile) {
    final rawPercent = profile.radiusCalibrationPercent.toDouble();
    final clamped = rawPercent.clamp(60, 140);
    return clamped / _legacyRadiusBaselinePercent;
  }

  double getSimulationSpreadFactor(BotProfile profile) {
    final rawPercent = profile.simulationSpreadPercent.toDouble();
    final clamped = rawPercent.clamp(70, 160);
    return clamped / _legacySimulationSpreadBaselinePercent;
  }

  double getScoringBaseRadius({
    required int skill,
    required BotProfile profile,
  }) {
    final clamped = skill.clamp(1, 1000);
    final normalized = clamped / 1000;
    final calibrationFactor = 1.1 * getRadiusCalibrationFactor(profile);
    final baseSpreadFactor = normalized >= 0.5
        ? 1 - (normalized - 0.5) * 0.08
        : 1 + (0.5 - normalized) * 0.18;
    final spreadScale = getSimulationSpreadFactor(profile);
    final spreadFactor = 1 + ((baseSpreadFactor - 1) * spreadScale);

    if (normalized >= 0.999) {
      return 9 * calibrationFactor * spreadFactor;
    }

    return (9 + 124 * pow(1 - normalized, 1.62)) *
        calibrationFactor *
        spreadFactor;
  }

  double getScoringScatterRadius({
    required BotProfile profile,
    required int score,
    required DartThrowResult target,
  }) {
    final radiusFactor = boardGeometry.radialFactorForPoint(
      _aimPointForThrow(target),
    );
    final pressure = score <= 80
        ? 1.08
        : score <= 170
        ? 1.03
        : 1;
    final baseRadius = getScoringBaseRadius(
      skill: profile.skill,
      profile: profile,
    );
    final tripleCenterFactor =
        (boardGeometry.radii.singleInner + boardGeometry.radii.tripleOuter) /
        2 /
        boardGeometry.radii.doubleOuter;

    if (baseRadius <= 0.001) {
      return 0;
    }

    final shapeFactor = 1 + (radiusFactor - tripleCenterFactor) * 0.18;
    return max(1.25, baseRadius * shapeFactor) * pressure;
  }

  double getCheckoutScatterRadius({
    required BotProfile profile,
    required int score,
    required DartThrowResult target,
  }) {
    final radiusFactor = boardGeometry.radialFactorForPoint(
      _aimPointForThrow(target),
    );
    final pressure = score <= 80 ? 1.1 : 1.02;
    final baseRadius = getScoringBaseRadius(
      skill: profile.finishingSkill,
      profile: profile,
    );
    final doubleCenterFactor =
        (boardGeometry.radii.singleOuter + boardGeometry.radii.doubleOuter) /
        2 /
        boardGeometry.radii.doubleOuter;

    if (baseRadius <= 0.001) {
      return 0;
    }

    final shapeFactor = 1 + (radiusFactor - doubleCenterFactor) * 0.18;
    return max(1.25, baseRadius * shapeFactor) * pressure;
  }

  double getScatterRadius({
    required BotProfile profile,
    required int score,
    required DartThrowResult target,
  }) {
    return isCheckoutField(target)
        ? getCheckoutScatterRadius(
            profile: profile,
            score: score,
            target: target,
          )
        : getScoringScatterRadius(
            profile: profile,
            score: score,
            target: target,
          );
  }

  bool isCheckoutField(DartThrowResult dartThrow) {
    return dartThrow.isDouble || dartThrow.isBull || dartThrow.label == '25';
  }

  BotThrowSimulation simulateThrow({
    required int score,
    required int dartsLeft,
    required BotProfile profile,
    CheckoutRequirement checkoutRequirement = CheckoutRequirement.doubleOut,
    CheckoutPlayStyle playStyle = CheckoutPlayStyle.balanced,
    Random? random,
  }) {
    final decideAimStopwatch = Stopwatch()..start();
    final decision = decideAim(
      profile: profile,
      score: score,
      dartsRemaining: dartsLeft,
      checkoutRequirement: checkoutRequirement,
      playStyle: playStyle,
    );
    decideAimStopwatch.stop();
    return simulateTargetThrow(
      target: decision.target,
      score: score,
      profile: profile,
      random: random,
      reason: decision.reason,
      plannedRoute: decision.route,
      precomputedAimDecisionMicroseconds:
          decideAimStopwatch.elapsedMicroseconds,
    );
  }

  BotThrowSimulation simulateTargetThrow({
    required DartThrowResult target,
    required int score,
    required BotProfile profile,
    Random? random,
    String reason = '',
    List<DartThrowResult> plannedRoute = const <DartThrowResult>[],
    int precomputedAimDecisionMicroseconds = 0,
  }) {
    final totalStopwatch = Stopwatch()..start();
    final activeRandom = random ?? Random();
    final aimPointStopwatch = Stopwatch()..start();
    final targetPoint = _aimPointForThrow(target);
    aimPointStopwatch.stop();
    final scatterPrepStopwatch = Stopwatch()..start();
    final baseScatterRadius = getScatterRadius(
      profile: profile,
      score: score,
      target: target,
    );
    scatterPrepStopwatch.stop();
    final throwModelStopwatch = Stopwatch()..start();
    final model = _buildThrowModel(
      profile: profile,
      score: score,
      target: target,
    );
    throwModelStopwatch.stop();
    final randomStopwatch = Stopwatch()..start();
    final jitter = (1 + (_nextGaussian(activeRandom) * model.consistencySigma))
        .clamp(0.72, 1.38);
    final scatterRadius = baseScatterRadius * model.pressureMultiplier * jitter;
    final sample = _randomUnitSample(activeRandom);
    randomStopwatch.stop();
    final projectStopwatch = Stopwatch()..start();
    final hitPoint = _projectScatterPoint(
      targetPoint: targetPoint,
      scatterRadius: scatterRadius,
      sample: sample,
      model: model,
    );
    projectStopwatch.stop();
    final classifyStopwatch = Stopwatch()..start();
    final hit = boardGeometry.classifyBoardPoint(
      hitPoint.x,
      hitPoint.y,
      rules: rules,
    );
    classifyStopwatch.stop();
    totalStopwatch.stop();
    final totalWithAimMicroseconds =
        totalStopwatch.elapsedMicroseconds + precomputedAimDecisionMicroseconds;
    _recordPerformanceSample(
      totalMicroseconds: totalWithAimMicroseconds,
      decideAimMicroseconds: precomputedAimDecisionMicroseconds,
      aimPointMicroseconds: aimPointStopwatch.elapsedMicroseconds,
      scatterPrepMicroseconds: scatterPrepStopwatch.elapsedMicroseconds,
      throwModelMicroseconds: throwModelStopwatch.elapsedMicroseconds,
      randomMicroseconds: randomStopwatch.elapsedMicroseconds,
      projectMicroseconds: projectStopwatch.elapsedMicroseconds,
      classifyMicroseconds: classifyStopwatch.elapsedMicroseconds,
    );
    return BotThrowSimulation(
      target: target,
      hit: hit,
      targetPoint: targetPoint,
      hitPoint: hitPoint,
      scatterRadius: scatterRadius,
      reason: reason,
      plannedRoute: plannedRoute,
    );
  }

  void _recordPerformanceSample({
    required int totalMicroseconds,
    required int decideAimMicroseconds,
    required int aimPointMicroseconds,
    required int scatterPrepMicroseconds,
    required int throwModelMicroseconds,
    required int randomMicroseconds,
    required int projectMicroseconds,
    required int classifyMicroseconds,
  }) {
    if (!recordPerformanceLogs) {
      return;
    }
    _perfTotals.record(
      totalMicrosecondsValue: totalMicroseconds,
      decideAimMicrosecondsValue: decideAimMicroseconds,
      aimPointMicrosecondsValue: aimPointMicroseconds,
      scatterPrepMicrosecondsValue: scatterPrepMicroseconds,
      throwModelMicrosecondsValue: throwModelMicroseconds,
      randomMicrosecondsValue: randomMicroseconds,
      projectMicrosecondsValue: projectMicroseconds,
      classifyMicrosecondsValue: classifyMicroseconds,
    );
    if (_perfTotals.throwCount % 50000 != 0) {
      return;
    }
    final otherMicroseconds =
        (_perfTotals.totalMicroseconds -
                _perfTotals.decideAimMicroseconds -
                _perfTotals.aimPointMicroseconds -
                _perfTotals.scatterPrepMicroseconds -
                _perfTotals.throwModelMicroseconds -
                _perfTotals.randomMicroseconds -
                _perfTotals.projectMicroseconds -
                _perfTotals.classifyMicroseconds)
            .clamp(0, 1 << 62);
    onPerformanceLog?.call(
      'Performance',
      'Bot-Kern ${_perfTotals.throwCount} Wuerfe | '
          'Gesamt ${_formatPerfMs(_perfTotals.totalMicroseconds)} ms | '
          'Aim ${_formatPerfMs(_perfTotals.decideAimMicroseconds)} ms | '
          'AimPoint ${_formatPerfMs(_perfTotals.aimPointMicroseconds)} ms | '
          'Scatter ${_formatPerfMs(_perfTotals.scatterPrepMicroseconds)} ms | '
          'Model ${_formatPerfMs(_perfTotals.throwModelMicroseconds)} ms | '
          'Random ${_formatPerfMs(_perfTotals.randomMicroseconds)} ms | '
          'Project ${_formatPerfMs(_perfTotals.projectMicroseconds)} ms | '
          'Classify ${_formatPerfMs(_perfTotals.classifyMicroseconds)} ms | '
          'Rest ${_formatPerfMs(otherMicroseconds)} ms',
    );
  }

  String _formatPerfMs(int microseconds) {
    return (microseconds / 1000.0).toStringAsFixed(1);
  }

  double estimateScoringAverage(BotProfile profile) {
    final target = rules.createTriple(20);
    final scatterRadius = getScoringScatterRadius(
      profile: profile,
      score: 501,
      target: target,
    );

    if (scatterRadius <= 0.001) {
      return 180;
    }

    final expectedPerDart = _estimateExpectedPointsForRadius(
      profile: profile,
      target: target,
      scatterRadius: scatterRadius,
      score: 501,
    );
    final normalizedSkill = profile.skill.clamp(1, 1000) / 1000;
    final compensationFactor = 1.035 + normalizedSkill * 0.02;
    return (expectedPerDart * 3 * compensationFactor).clamp(0, 180);
  }

  double estimateFinishingStrength(BotProfile profile) {
    final doubleTarget = rules.createDouble(16);
    final doubleRadius = getCheckoutScatterRadius(
      profile: profile,
      score: 32,
      target: doubleTarget,
    );
    final doubleHitRate = _estimateHitRateForThrow(
      profile: profile,
      target: doubleTarget,
      scatterRadius: doubleRadius,
      score: 32,
    );

    final bullTarget = rules.createBull();
    final bullRadius = getCheckoutScatterRadius(
      profile: profile,
      score: 50,
      target: bullTarget,
    );
    final bullHitRate = _estimateHitRateForThrow(
      profile: profile,
      target: bullTarget,
      scatterRadius: bullRadius,
      score: 50,
    );

    return (doubleHitRate * 0.85 + bullHitRate * 0.15).clamp(0, 1);
  }

  double _estimateRawThreeDartAverage(BotProfile profile) {
    final scoringAverage = estimateScoringAverage(profile);
    final finishingStrength = estimateFinishingStrength(profile);
    final finishFactor = 0.79 + finishingStrength * 0.2;
    return (scoringAverage * finishFactor).clamp(0, 180);
  }

  double estimateFallbackThreeDartAverage(BotProfile profile) {
    return _estimateRawThreeDartAverage(profile).toDouble();
  }

  double estimateThreeDartAverage(
    BotProfile profile, {
    bool forceRecalibrate = false,
  }) {
    final cacheKey = getTheoreticalAverageCacheKey(profile);
    if (!forceRecalibrate && _theoreticalAverageCache.containsKey(cacheKey)) {
      return _theoreticalAverageCache[cacheKey]!;
    }

    final value = _calculateCalibratedThreeDartAverage(
      profile: profile,
      cacheKey: cacheKey,
    );
    _theoreticalAverageCache[cacheKey] = value;
    return value;
  }

  double _calculateCalibratedThreeDartAverage({
    required BotProfile profile,
    required String cacheKey,
  }) {
    final structuralAverage = estimateFallbackThreeDartAverage(profile);
    final simulatedAverage = _calculateLongRunSimulationAverage(
      profile: profile,
      cacheKey: cacheKey,
    );
    final profileAnchorAverage = _estimateProfileAnchorAverage(profile);
    final orderingBias = _buildOrderingBias(profile);
    return ((structuralAverage * 0.45) +
            (simulatedAverage * 0.38) +
            (profileAnchorAverage * 0.17) +
            orderingBias)
        .clamp(0, 180)
        .toDouble();
  }

  double _calculateLongRunSimulationAverage({
    required BotProfile profile,
    required String cacheKey,
  }) {
    var grandTotalScored = 0;
    var grandTotalDarts = 0;
    const passes = 5;
    const legsToSimulate = 28;

    for (var pass = 0; pass < passes; pass += 1) {
      final seededRandom = _SeededRandom('$cacheKey|$pass');

      for (var leg = 0; leg < legsToSimulate; leg += 1) {
        var score = 501;
        var safety = 0;

        while (score > 0 && safety < 120) {
          final startScore = score;
          var visitScored = 0;
          var busted = false;

          for (var dart = 1; dart <= 3; dart += 1) {
            final simulation = simulateThrow(
              score: score,
              dartsLeft: 4 - dart,
              profile: profile,
              random: seededRandom,
            );
            final chosenThrow = simulation.hit;
            final newScore = score - chosenThrow.scoredPoints;
            grandTotalDarts += 1;

            if (newScore < 0 || newScore == 1) {
              score = startScore;
              busted = true;
              break;
            }

            if (newScore == 0) {
              if (chosenThrow.isFinishDouble) {
                visitScored += chosenThrow.scoredPoints;
                grandTotalScored += visitScored;
                score = 0;
              } else {
                score = startScore;
              }
              busted = true;
              break;
            }

            visitScored += chosenThrow.scoredPoints;
            score = newScore;
          }

          if (!busted) {
            grandTotalScored += visitScored;
          }

          safety += 1;
        }
      }
    }

    if (grandTotalDarts <= 0) {
      return 0;
    }

    return ((grandTotalScored / grandTotalDarts) * 3).clamp(0, 180).toDouble();
  }

  double _estimateProfileAnchorAverage(BotProfile profile) {
    final scoringSkill = profile.skill.clamp(1, 1000) / 1000;
    final finishingSkill = profile.finishingSkill.clamp(1, 1000) / 1000;
    return (14 + (scoringSkill * 54) + (finishingSkill * 56))
        .clamp(0, 180)
        .toDouble();
  }

  double _buildOrderingBias(BotProfile profile) {
    final blendedSkill =
        ((profile.skill.clamp(1, 1000) * 0.65) +
            (profile.finishingSkill.clamp(1, 1000) * 0.35)) /
        1000;
    return blendedSkill * 0.08;
  }

  double recalibrateThreeDartAverage(BotProfile profile) {
    final cacheKey = getTheoreticalAverageCacheKey(profile);
    _theoreticalAverageCache.remove(cacheKey);
    return estimateThreeDartAverage(profile, forceRecalibrate: true);
  }

  String getTheoreticalAverageCacheKey(BotProfile profile) {
    return <String>[
      'v11b',
      'board-geometry-2',
      profile.skill.round().toString(),
      profile.finishingSkill.round().toString(),
      profile.radiusCalibrationPercent.round().toString(),
      profile.simulationSpreadPercent.round().toString(),
    ].join('|');
  }

  List<DartThrowResult>? findPreferredCheckout({
    required int score,
    required int dartsLeft,
    CheckoutRequirement checkoutRequirement = CheckoutRequirement.doubleOut,
    CheckoutPlayStyle playStyle = CheckoutPlayStyle.balanced,
  }) {
    final cacheKey =
        '$score|$dartsLeft|${checkoutRequirement.name}|${playStyle.name}';
    if (_preferredCheckoutCache.containsKey(cacheKey)) {
      return _preferredCheckoutCache[cacheKey];
    }

    final routes = FixedCheckouts.routes(
      score,
      dartsLeft: dartsLeft,
      requirement: checkoutRequirement,
    );
    final best = routes.isEmpty ? null : routes.first;
    if (best == null || best.isEmpty) {
      _preferredCheckoutCache[cacheKey] = null;
      return null;
    }
    _preferredCheckoutCache[cacheKey] = best;
    return best;
  }

  DartThrowResult? findPreferredSetupTarget({
    required int score,
    required int dartsLeft,
    CheckoutRequirement checkoutRequirement = CheckoutRequirement.doubleOut,
    CheckoutPlayStyle playStyle = CheckoutPlayStyle.balanced,
  }) {
    final cacheKey =
        '$score|$dartsLeft|${checkoutRequirement.name}|${playStyle.name}';
    if (_preferredSetupTargetCache.containsKey(cacheKey)) {
      return _preferredSetupTargetCache[cacheKey];
    }

    if (dartsLeft <= 0 || score <= 1) {
      _preferredSetupTargetCache[cacheKey] = null;
      return null;
    }

    final setupRoute = findPreferredSetupRoute(
      score: score,
      dartsLeft: dartsLeft,
      checkoutRequirement: checkoutRequirement,
      playStyle: playStyle,
    );
    if (setupRoute != null && setupRoute.isNotEmpty) {
      final target = setupRoute.first;
      _preferredSetupTargetCache[cacheKey] = target;
      return target;
    }

    if (dartsLeft == 1 || score > 170) {
      final leaveTarget = findPreferredLeaveTarget(
        score,
        checkoutRequirement: checkoutRequirement,
        playStyle: playStyle,
      );
      _preferredSetupTargetCache[cacheKey] = leaveTarget;
      return leaveTarget;
    }

    _preferredSetupTargetCache[cacheKey] = null;
    return null;
  }

  DartThrowResult? findInVisitSetupTarget({
    required int score,
    required int dartsLeft,
    CheckoutRequirement checkoutRequirement = CheckoutRequirement.doubleOut,
    CheckoutPlayStyle playStyle = CheckoutPlayStyle.balanced,
  }) {
    final cacheKey =
        '$score|$dartsLeft|${checkoutRequirement.name}|${playStyle.name}';
    if (_inVisitSetupTargetCache.containsKey(cacheKey)) {
      return _inVisitSetupTargetCache[cacheKey];
    }

    if (dartsLeft <= 1) {
      _inVisitSetupTargetCache[cacheKey] = null;
      return null;
    }

    final setupRoute = findPreferredSetupRoute(
      score: score,
      dartsLeft: dartsLeft,
      checkoutRequirement: checkoutRequirement,
      playStyle: playStyle,
    );
    if (setupRoute == null || setupRoute.isEmpty) {
      _inVisitSetupTargetCache[cacheKey] = null;
      return null;
    }

    final best = setupRoute.first;
    _inVisitSetupTargetCache[cacheKey] = best;
    return best;
  }

  List<DartThrowResult>? findPreferredSetupRoute({
    required int score,
    required int dartsLeft,
    CheckoutRequirement checkoutRequirement = CheckoutRequirement.doubleOut,
    CheckoutPlayStyle playStyle = CheckoutPlayStyle.balanced,
  }) {
    final cacheKey =
        '$score|$dartsLeft|${checkoutRequirement.name}|${playStyle.name}';
    if (_preferredSetupRouteCache.containsKey(cacheKey)) {
      return _preferredSetupRouteCache[cacheKey];
    }

    if (dartsLeft <= 1 || score <= 1 || score > 170) {
      _preferredSetupRouteCache[cacheKey] = null;
      return null;
    }

    final route =
        CheckoutRouteRepository.instance.bestSetupRoute(
          score: score,
          dartsLeft: dartsLeft,
          checkoutRequirement: checkoutRequirement,
          playStyle: playStyle,
        ) ??
        _bestPlannerSetupRoute(
          score: score,
          dartsLeft: dartsLeft,
          checkoutRequirement: checkoutRequirement,
          playStyle: playStyle,
        );
    if (route == null || route.isEmpty) {
      _preferredSetupRouteCache[cacheKey] = null;
      return null;
    }

    _preferredSetupRouteCache[cacheKey] = route;
    return route;
  }

  List<DartThrowResult>? findPreferredHighScoreSetupRoute({
    required int score,
    required int dartsLeft,
    CheckoutRequirement checkoutRequirement = CheckoutRequirement.doubleOut,
    CheckoutPlayStyle playStyle = CheckoutPlayStyle.balanced,
  }) {
    final cacheKey =
        '$score|$dartsLeft|${checkoutRequirement.name}|${playStyle.name}';
    if (_preferredHighScoreSetupRouteCache.containsKey(cacheKey)) {
      return _preferredHighScoreSetupRouteCache[cacheKey];
    }

    if (dartsLeft != 3 || score < 350) {
      _preferredHighScoreSetupRouteCache[cacheKey] = null;
      return null;
    }

    final route =
        CheckoutRouteRepository.instance.bestHighScoreSetupRoute(
          score: score,
          dartsLeft: dartsLeft,
          checkoutRequirement: checkoutRequirement,
          playStyle: playStyle,
        ) ??
        _bestPlannerSetupRoute(
          score: score,
          dartsLeft: dartsLeft,
          checkoutRequirement: checkoutRequirement,
          playStyle: playStyle,
        );
    if (route == null || route.isEmpty) {
      _preferredHighScoreSetupRouteCache[cacheKey] = null;
      return null;
    }

    _preferredHighScoreSetupRouteCache[cacheKey] = route;
    return route;
  }

  List<DartThrowResult>? _bestPlannerSetupRoute({
    required int score,
    required int dartsLeft,
    CheckoutRequirement checkoutRequirement = CheckoutRequirement.doubleOut,
    CheckoutPlayStyle playStyle = CheckoutPlayStyle.balanced,
  }) {
    final options = checkoutPlanner.setupLeaveOptions(
      startScore: score,
      dartsLeft: dartsLeft,
      checkoutRequirement: checkoutRequirement,
      playStyle: playStyle,
      leavePreference: 85,
      outerBullPreference: 50,
      bullPreference: 50,
      maxResults: 1,
      maxResultsPerNarrowCount: 20,
    );
    if (options.isEmpty) {
      return null;
    }
    return options.first.setupRoute;
  }

  DartThrowResult? findPreferredLeaveTarget(
    int score, {
    CheckoutRequirement checkoutRequirement = CheckoutRequirement.doubleOut,
    CheckoutPlayStyle playStyle = CheckoutPlayStyle.balanced,
  }) {
    final cacheKey = '$score|${checkoutRequirement.name}|${playStyle.name}';
    if (_preferredLeaveTargetCache.containsKey(cacheKey)) {
      return _preferredLeaveTargetCache[cacheKey];
    }

    _LeaveCandidate? bestCandidate;
    for (final dartThrow in _allThrows) {
      if (dartThrow.scoredPoints <= 0 || dartThrow.isBull) {
        continue;
      }

      final rest = score - dartThrow.scoredPoints;
      if (rest < 2) {
        continue;
      }

      final candidate = _LeaveCandidate(
        target: dartThrow,
        rest: rest,
        leavePreference: getLeavePreference(
          rest,
          checkoutRequirement: checkoutRequirement,
          playStyle: playStyle,
        ),
      );

      if (bestCandidate == null ||
          _compareLeaveCandidates(
                candidate,
                bestCandidate,
                checkoutRequirement: checkoutRequirement,
                playStyle: playStyle,
              ) <
              0) {
        bestCandidate = candidate;
      }
    }

    final bestTarget = bestCandidate?.target;
    _preferredLeaveTargetCache[cacheKey] = bestTarget;
    return bestTarget;
  }

  List<List<DartThrowResult>> collectCheckoutRoutes({
    required int score,
    required int dartsLeft,
    List<DartThrowResult> prefix = const <DartThrowResult>[],
  }) {
    if (prefix.isEmpty) {
      final cacheKey = '$score|$dartsLeft';
      if (_checkoutRoutesCache.containsKey(cacheKey)) {
        return _checkoutRoutesCache[cacheKey]!;
      }
    }

    if (dartsLeft <= 0) {
      return score == 0
          ? <List<DartThrowResult>>[prefix]
          : <List<DartThrowResult>>[];
    }

    final routes = <List<DartThrowResult>>[];
    for (final dartThrow in _allThrows) {
      final rest = score - dartThrow.scoredPoints;
      if (rest < 0 || rest == 1) {
        continue;
      }

      if (rest == 0) {
        if (dartThrow.isDouble) {
          routes.add(<DartThrowResult>[...prefix, dartThrow]);
        }
        continue;
      }

      routes.addAll(
        collectCheckoutRoutes(
          score: rest,
          dartsLeft: dartsLeft - 1,
          prefix: <DartThrowResult>[...prefix, dartThrow],
        ),
      );
    }

    if (prefix.isEmpty) {
      _checkoutRoutesCache['$score|$dartsLeft'] = routes;
    }
    return routes;
  }

  int getLeavePreference(
    int rest, {
    CheckoutRequirement checkoutRequirement = CheckoutRequirement.doubleOut,
    CheckoutPlayStyle playStyle = CheckoutPlayStyle.balanced,
  }) {
    final cacheKey = '$rest|${checkoutRequirement.name}|${playStyle.name}';
    if (_leavePreferenceCache.containsKey(cacheKey)) {
      return _leavePreferenceCache[cacheKey]!;
    }

    late final int value;
    if (rest == 50) {
      value = 50;
    } else if (rest > 1 && rest <= 40 && rest.isEven) {
      value = 10000 + getFinishPreference(rules.createDouble(rest ~/ 2));
    } else {
      final checkoutRoute = findPreferredCheckout(
        score: rest,
        dartsLeft: 3,
        checkoutRequirement: checkoutRequirement,
        playStyle: playStyle,
      );
      if (checkoutRoute != null && checkoutRoute.isNotEmpty) {
        final finalThrow = checkoutRoute.last;
        value =
            8000 -
            countNarrowFields(checkoutRoute) * 200 -
            checkoutRoute.length * 30 -
            getBullPenalty(checkoutRoute) +
            getFinishPreference(finalThrow);
      } else if (isBogeyNumber(rest)) {
        value = -500 - rest;
      } else if (rest > 170) {
        value = 500 - (rest - 170).abs();
      } else {
        value = 100 - rest;
      }
    }

    _leavePreferenceCache[cacheKey] = value;
    return value;
  }

  int getLeaveBullPenalty(
    int rest, {
    CheckoutRequirement checkoutRequirement = CheckoutRequirement.doubleOut,
    CheckoutPlayStyle playStyle = CheckoutPlayStyle.balanced,
  }) {
    final cacheKey = '$rest|${checkoutRequirement.name}|${playStyle.name}';
    if (_leaveBullPenaltyCache.containsKey(cacheKey)) {
      return _leaveBullPenaltyCache[cacheKey]!;
    }

    if (rest == 50) {
      _leaveBullPenaltyCache[cacheKey] = 200;
      return 200;
    }

    final route = findPreferredCheckout(
      score: rest,
      dartsLeft: 3,
      checkoutRequirement: checkoutRequirement,
      playStyle: playStyle,
    );
    final penalty = route == null ? 0 : getBullPenalty(route);
    _leaveBullPenaltyCache[cacheKey] = penalty;
    return penalty;
  }

  bool isBogeyNumber(int score) {
    return score == 169 ||
        score == 168 ||
        score == 166 ||
        score == 165 ||
        score == 163 ||
        score == 162 ||
        score == 159;
  }

  int countNarrowFields(List<DartThrowResult> route) {
    return route.fold<int>(
      0,
      (sum, dartThrow) => sum + (isNarrowField(dartThrow) ? 1 : 0),
    );
  }

  bool isNarrowField(DartThrowResult dartThrow) {
    if (dartThrow.isDouble || dartThrow.isTriple || dartThrow.isBull) {
      return true;
    }
    return dartThrow.label == '25';
  }

  int getBullPenalty(List<DartThrowResult> route) {
    var sum = 0;
    for (var index = 0; index < route.length; index += 1) {
      final dartThrow = route[index];
      if (dartThrow.isBull) {
        sum += index == route.length - 1 ? 1000 : 250;
      } else if (dartThrow.label == '25') {
        sum += 120;
      }
    }
    return sum;
  }

  int getFinishPreference(DartThrowResult finalDart) {
    if (finalDart.isBull) {
      return -1;
    }

    var value = finalDart.baseValue;
    var twos = 0;
    while (value > 0 && value.isEven) {
      twos += 1;
      value ~/= 2;
    }
    return twos * 100 + finalDart.baseValue;
  }

  int getSetupPreference(List<DartThrowResult> route) {
    var sum = 0;
    for (var index = 0; index < route.length; index += 1) {
      final weight = route.length - index;
      sum += route[index].scoredPoints * weight;
    }
    return sum;
  }

  int getThrowTargetPenalty(DartThrowResult? dartThrow) {
    if (dartThrow == null) {
      return 0;
    }
    if (dartThrow.isBull) {
      return 1000;
    }
    if (dartThrow.label == '25') {
      return 220;
    }
    if (dartThrow.isDouble) {
      return 120;
    }
    if (dartThrow.isTriple) {
      return 40;
    }
    return 0;
  }

  double _estimateExpectedPointsForRadius({
    required BotProfile profile,
    required DartThrowResult target,
    required double scatterRadius,
    required int score,
  }) {
    final targetPoint = _aimPointForThrow(target);
    final model = _buildThrowModel(
      profile: profile,
      score: score,
      target: target,
    );
    var totalPoints = 0.0;
    for (final sample in _circleSamplePattern) {
      final hitPoint = _projectScatterPoint(
        targetPoint: targetPoint,
        scatterRadius: scatterRadius * model.pressureMultiplier,
        sample: sample,
        model: model,
      );
      final hit = boardGeometry.classifyBoardPoint(
        hitPoint.x,
        hitPoint.y,
        rules: rules,
      );
      totalPoints += hit.scoredPoints;
    }
    return totalPoints / _circleSamplePattern.length;
  }

  double _estimateHitRateForThrow({
    required BotProfile profile,
    required DartThrowResult target,
    required double scatterRadius,
    required int score,
  }) {
    if (scatterRadius <= 0.001) {
      return 1;
    }

    final targetPoint = _aimPointForThrow(target);
    final model = _buildThrowModel(
      profile: profile,
      score: score,
      target: target,
    );
    var hits = 0;
    for (final sample in _circleSamplePattern) {
      final hitPoint = _projectScatterPoint(
        targetPoint: targetPoint,
        scatterRadius: scatterRadius * model.pressureMultiplier,
        sample: sample,
        model: model,
      );
      final hit = boardGeometry.classifyBoardPoint(
        hitPoint.x,
        hitPoint.y,
        rules: rules,
      );
      if (hit.label == target.label) {
        hits += 1;
      }
    }
    return hits / _circleSamplePattern.length;
  }

  int _compareLeaveCandidates(
    _LeaveCandidate a,
    _LeaveCandidate b, {
    CheckoutRequirement checkoutRequirement = CheckoutRequirement.doubleOut,
    CheckoutPlayStyle playStyle = CheckoutPlayStyle.balanced,
  }) {
    if (a.leavePreference != b.leavePreference) {
      return b.leavePreference - a.leavePreference;
    }

    final aBullPenalty = getLeaveBullPenalty(
      a.rest,
      checkoutRequirement: checkoutRequirement,
      playStyle: playStyle,
    );
    final bBullPenalty = getLeaveBullPenalty(
      b.rest,
      checkoutRequirement: checkoutRequirement,
      playStyle: playStyle,
    );
    if (aBullPenalty != bBullPenalty) {
      return aBullPenalty - bBullPenalty;
    }

    final aTargetPenalty = getThrowTargetPenalty(a.target);
    final bTargetPenalty = getThrowTargetPenalty(b.target);
    if (aTargetPenalty != bTargetPenalty) {
      return aTargetPenalty - bTargetPenalty;
    }

    return b.target.scoredPoints - a.target.scoredPoints;
  }

  _ThrowModel _buildThrowModel({
    required BotProfile profile,
    required int score,
    required DartThrowResult target,
  }) {
    final cacheKey = <String>[
      target.label,
      score.toString(),
      profile.skill.toString(),
      profile.finishingSkill.toString(),
      profile.radiusCalibrationPercent.toString(),
      profile.simulationSpreadPercent.toString(),
    ].join('|');
    final cached = _throwModelCache[cacheKey];
    if (cached != null) {
      return cached;
    }

    final skillNorm = profile.skill.clamp(1, 1000) / 1000;
    final finishNorm = profile.finishingSkill.clamp(1, 1000) / 1000;
    final accuracyNorm = isCheckoutField(target) ? finishNorm : skillNorm;
    final consistencyNorm = ((skillNorm * 0.7) + (finishNorm * 0.3)).clamp(
      0,
      1,
    );
    final checkoutFocus = (0.58 + finishNorm * 0.32).clamp(0, 1);

    final narrowTarget = target.isTriple || target.isDouble || target.isBull;
    final tangentialBase = target.isTriple
        ? 1.26
        : target.isDouble
        ? 1.18
        : target.isBull
        ? 1.08
        : 0.98;
    final radialBase = target.isTriple
        ? 0.94
        : target.isDouble
        ? 0.9
        : target.isBull
        ? 0.88
        : 1.0;

    final radialScale =
        (radialBase - accuracyNorm * (narrowTarget ? 0.18 : 0.1)).clamp(
          0.62,
          1.05,
        );
    final tangentialScale =
        (tangentialBase - accuracyNorm * (narrowTarget ? 0.2 : 0.08)).clamp(
          0.72,
          1.3,
        );

    final radialBias =
        (target.isDouble
                ? (-0.16 + accuracyNorm * 0.08)
                : target.isTriple
                ? (-0.06 + accuracyNorm * 0.04)
                : target.isBull
                ? 0
                : (-0.01 + accuracyNorm * 0.02))
            .toDouble();

    final pressureMultiplier =
        (score <= 80
                ? (1.08 - checkoutFocus * 0.1).clamp(0.93, 1.08)
                : score <= 170
                ? (1.04 - checkoutFocus * 0.05).clamp(0.96, 1.04)
                : 1.0)
            .toDouble();

    final consistencySigma = (0.24 - consistencyNorm * 0.14)
        .clamp(0.06, 0.2)
        .toDouble();

    final model = _ThrowModel(
      radialScale: radialScale,
      tangentialScale: tangentialScale,
      radialBias: radialBias,
      consistencySigma: consistencySigma,
      pressureMultiplier: pressureMultiplier,
    );
    _throwModelCache[cacheKey] = model;
    return model;
  }

  BoardPoint _projectScatterPoint({
    required BoardPoint targetPoint,
    required double scatterRadius,
    required BoardPoint sample,
    required _ThrowModel model,
  }) {
    final dx = targetPoint.x - boardGeometry.center.x;
    final dy = targetPoint.y - boardGeometry.center.y;
    final distance = sqrt(dx * dx + dy * dy);
    final radialX = distance <= 0.0001 ? 0.0 : dx / distance;
    final radialY = distance <= 0.0001 ? -1.0 : dy / distance;
    final tangentX = -radialY;
    final tangentY = radialX;

    final radialDistance =
        (sample.x * model.radialScale + model.radialBias) * scatterRadius;
    final tangentialDistance = sample.y * model.tangentialScale * scatterRadius;

    return BoardPoint(
      targetPoint.x + radialX * radialDistance + tangentX * tangentialDistance,
      targetPoint.y + radialY * radialDistance + tangentY * tangentialDistance,
    );
  }

  BoardPoint _randomUnitSample(Random random) {
    final angle = random.nextDouble() * pi * 2;
    final radius = sqrt(random.nextDouble());
    return BoardPoint(cos(angle) * radius, sin(angle) * radius);
  }

  double _nextGaussian(Random random) {
    final u1 = max(random.nextDouble(), 1e-9);
    final u2 = random.nextDouble();
    return sqrt(-2 * log(u1)) * cos(2 * pi * u2);
  }

  BoardPoint _aimPointForThrow(DartThrowResult target) {
    return _aimPointCache.putIfAbsent(
      target.label,
      () => boardGeometry.aimPointForThrow(target),
    );
  }
}

final List<BoardPoint> _circleSamplePattern = _buildCircleSamplePattern();

List<BoardPoint> _buildCircleSamplePattern() {
  const sampleCount = 257;
  final samples = <BoardPoint>[];
  final goldenAngle = pi * (3 - sqrt(5));

  for (var index = 0; index < sampleCount; index += 1) {
    final radius = sqrt((index + 0.5) / sampleCount);
    final angle = index * goldenAngle;
    samples.add(BoardPoint(cos(angle) * radius, sin(angle) * radius));
  }

  return samples;
}

class _SeededRandom implements Random {
  _SeededRandom(String seedText) : _seed = _initialSeed(seedText);

  int _seed;

  static int _initialSeed(String seedText) {
    var seed = 2166136261;
    final text = seedText.isEmpty ? 'dart-bot' : seedText;
    for (var index = 0; index < text.length; index += 1) {
      seed ^= text.codeUnitAt(index);
      seed = (seed * 16777619) & 0xFFFFFFFF;
    }
    return seed & 0xFFFFFFFF;
  }

  int _nextRaw() {
    _seed = (_seed + 0x6D2B79F5) & 0xFFFFFFFF;
    var value = _seed;
    value = ((value ^ (value >> 15)) * (value | 1)) & 0xFFFFFFFF;
    value ^= value + ((((value ^ (value >> 7)) * (value | 61)) & 0xFFFFFFFF));
    return (value ^ (value >> 14)) & 0xFFFFFFFF;
  }

  @override
  bool nextBool() => nextDouble() >= 0.5;

  @override
  double nextDouble() => _nextRaw() / 4294967296;

  @override
  int nextInt(int max) {
    if (max <= 0) {
      throw ArgumentError.value(max, 'max', 'Must be positive');
    }
    return _nextRaw() % max;
  }
}
