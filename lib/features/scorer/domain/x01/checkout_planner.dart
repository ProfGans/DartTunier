import 'x01_models.dart';
import 'x01_rules.dart';

class CheckoutContinuationPlan {
  const CheckoutContinuationPlan({
    required this.throws,
    required this.immediateFinish,
    required this.score,
  });

  final List<DartThrowResult> throws;
  final bool immediateFinish;
  final int score;
}

class CheckoutSetupLeaveOption {
  const CheckoutSetupLeaveOption({
    required this.setupRoute,
    required this.remainingScore,
    required this.finishRoute,
    required this.score,
    required this.breakdown,
  });

  final List<DartThrowResult> setupRoute;
  final int remainingScore;
  final List<DartThrowResult> finishRoute;
  final int score;
  final CheckoutSetupScoreBreakdown breakdown;
}

enum CheckoutSetupFinishBand { deep, medium, justFinish }

class CheckoutRouteScoreBreakdown {
  const CheckoutRouteScoreBreakdown({
    required this.dartPathScore,
    required this.comfort,
    required this.robustness,
    required this.doubleQuality,
    required this.narrowFieldPenalty,
    required this.bullPenalty,
    required this.segmentFlow,
    required this.dartPathDetails,
    required this.comfortDetails,
    required this.robustnessDetails,
    required this.doubleQualityDetails,
    required this.narrowFieldDetails,
    required this.bullPenaltyDetails,
    required this.segmentFlowDetails,
  });

  final int dartPathScore;
  final int comfort;
  final int robustness;
  final int doubleQuality;
  final int narrowFieldPenalty;
  final int bullPenalty;
  final int segmentFlow;
  final List<String> dartPathDetails;
  final List<String> comfortDetails;
  final List<String> robustnessDetails;
  final List<String> doubleQualityDetails;
  final List<String> narrowFieldDetails;
  final List<String> bullPenaltyDetails;
  final List<String> segmentFlowDetails;
}

class CheckoutSetupScoreBreakdown {
  const CheckoutSetupScoreBreakdown({
    required this.setupPathScore,
    required this.routeGuidance,
    required this.leaveQuality,
    required this.missPenalty,
    required this.totalScore,
    required this.setupPathDetails,
    required this.routeGuidanceDetails,
    required this.leaveQualityDetails,
    required this.missPenaltyDetails,
  });

  final int setupPathScore;
  final int routeGuidance;
  final int leaveQuality;
  final int missPenalty;
  final int totalScore;
  final List<String> setupPathDetails;
  final List<String> routeGuidanceDetails;
  final List<String> leaveQualityDetails;
  final List<String> missPenaltyDetails;
}

class _ScoreDetails {
  const _ScoreDetails({required this.total, required this.details});

  final int total;
  final List<String> details;
}

class _SetupComfortRelief {
  const _SetupComfortRelief({required this.total, required this.details});

  final int total;
  final List<String> details;
}

class CheckoutPlanner {
  CheckoutPlanner({X01Rules? rules})
    : rules = rules ?? const X01Rules(),
      _allThrows = (rules ?? const X01Rules()).buildAllThrows();

  final X01Rules rules;
  final List<DartThrowResult> _allThrows;

  final Map<String, List<List<DartThrowResult>>> _checkoutRoutesCache =
      <String, List<List<DartThrowResult>>>{};
  final Map<String, List<List<DartThrowResult>>> _targetRoutesCache =
      <String, List<List<DartThrowResult>>>{};
  final Map<String, List<DartThrowResult>?> _finishRouteCache =
      <String, List<DartThrowResult>?>{};
  final Map<String, List<DartThrowResult>?> _finishRouteByTypeCache =
      <String, List<DartThrowResult>?>{};
  final Map<String, List<DartThrowResult>?> _targetRouteCache =
      <String, List<DartThrowResult>?>{};
  final Map<String, CheckoutContinuationPlan?> _continuationPlanCache =
      <String, CheckoutContinuationPlan?>{};
  final Map<String, CheckoutRouteScoreBreakdown> _routeScoreBreakdownCache =
      <String, CheckoutRouteScoreBreakdown>{};
  final Map<String, CheckoutSetupScoreBreakdown> _setupScoreBreakdownCache =
      <String, CheckoutSetupScoreBreakdown>{};
  final Map<String, List<CheckoutSetupLeaveOption>> _topSetupLeavesCache =
      <String, List<CheckoutSetupLeaveOption>>{};
  final Map<String, List<CheckoutSetupLeaveOption>> _setupLeaveOptionsCache =
      <String, List<CheckoutSetupLeaveOption>>{};
  final Map<String, Map<CheckoutSetupFinishBand, CheckoutSetupLeaveOption>>
  _setupBandOptionsCache =
      <String, Map<CheckoutSetupFinishBand, CheckoutSetupLeaveOption>>{};
  final Map<String, List<DartThrowResult>?> _setupFallbackRouteCache =
      <String, List<DartThrowResult>?>{};

  void clearCaches() {
    _checkoutRoutesCache.clear();
    _targetRoutesCache.clear();
    _finishRouteCache.clear();
    _finishRouteByTypeCache.clear();
    _targetRouteCache.clear();
    _continuationPlanCache.clear();
    _routeScoreBreakdownCache.clear();
    _setupScoreBreakdownCache.clear();
    _topSetupLeavesCache.clear();
    _setupLeaveOptionsCache.clear();
    _setupBandOptionsCache.clear();
    _setupFallbackRouteCache.clear();
  }

  bool isValidSetupStartScore(int score) {
    const bogeySetupScores = <int>{159, 162, 163, 165, 166, 168, 169};
    return score >= 171 || bogeySetupScores.contains(score);
  }

  bool isAllowedSetupRoute(List<DartThrowResult> route) {
    return !route.any((entry) => entry.isDouble && !entry.isBull);
  }

  int doublePreferenceAdjustment(
    DartThrowResult? finalThrow, {
    required Set<int> preferredDoubles,
    required Set<int> dislikedDoubles,
  }) {
    if (finalThrow == null || !finalThrow.isFinishDouble || finalThrow.isBull) {
      return 0;
    }
    if (preferredDoubles.contains(finalThrow.baseValue)) {
      return 150;
    }
    if (dislikedDoubles.contains(finalThrow.baseValue)) {
      return -150;
    }
    return 0;
  }

  int setupLeaveEffectiveScore(
    CheckoutSetupLeaveOption option, {
    required Set<int> preferredDoubles,
    required Set<int> dislikedDoubles,
  }) {
    return option.score +
        doublePreferenceAdjustment(
          option.finishRoute.isEmpty ? null : option.finishRoute.last,
          preferredDoubles: preferredDoubles,
          dislikedDoubles: dislikedDoubles,
        );
  }

  List<CheckoutSetupLeaveOption> setupLeaveOptions({
    required int startScore,
    required int dartsLeft,
    CheckoutRequirement checkoutRequirement = CheckoutRequirement.doubleOut,
    CheckoutPlayStyle playStyle = CheckoutPlayStyle.balanced,
    int leavePreference = 50,
    int outerBullPreference = 50,
    int bullPreference = 50,
    int maxResults = 8,
    int maxResultsPerNarrowCount = 20,
    Set<int> preferredDoubles = const <int>{},
    Set<int> dislikedDoubles = const <int>{},
  }) {
    final sortedPreferred = preferredDoubles.toList()..sort();
    final sortedDisliked = dislikedDoubles.toList()..sort();
    final cacheKey = <Object>[
      startScore,
      dartsLeft,
      checkoutRequirement,
      playStyle,
      leavePreference,
      outerBullPreference,
      bullPreference,
      maxResults,
      maxResultsPerNarrowCount,
      sortedPreferred,
      sortedDisliked,
    ].join('|');
    final cached = _setupLeaveOptionsCache[cacheKey];
    if (cached != null) {
      return cached;
    }
    if (!isValidSetupStartScore(startScore) || dartsLeft <= 0) {
      return const <CheckoutSetupLeaveOption>[];
    }

    final options = <CheckoutSetupLeaveOption>[];
    for (var narrowCount = 0; narrowCount < 4; narrowCount += 1) {
      options.addAll(
        topSetupLeavesForNarrowFieldCount(
          startScore: startScore,
          dartsLeft: dartsLeft,
          narrowFieldCount: narrowCount,
          checkoutRequirement: checkoutRequirement,
          playStyle: playStyle,
          leavePreference: leavePreference,
          outerBullPreference: outerBullPreference,
          bullPreference: bullPreference,
          maxResults: maxResultsPerNarrowCount,
        ),
      );
    }

    final deduped = <String, CheckoutSetupLeaveOption>{};
    for (final option in options) {
      if (!isAllowedSetupRoute(option.setupRoute)) {
        continue;
      }
      final key = option.setupRoute.map((entry) => entry.label).join('|');
      final existing = deduped[key];
      if (existing == null ||
          setupLeaveEffectiveScore(
                option,
                preferredDoubles: preferredDoubles,
                dislikedDoubles: dislikedDoubles,
              ) >
              setupLeaveEffectiveScore(
                existing,
                preferredDoubles: preferredDoubles,
                dislikedDoubles: dislikedDoubles,
              )) {
        deduped[key] = option;
      }
    }

    final results = deduped.values.toList()
      ..sort(
        (a, b) =>
            setupLeaveEffectiveScore(
              b,
              preferredDoubles: preferredDoubles,
              dislikedDoubles: dislikedDoubles,
            ).compareTo(
              setupLeaveEffectiveScore(
                a,
                preferredDoubles: preferredDoubles,
                dislikedDoubles: dislikedDoubles,
              ),
            ),
      );

    final output = List<CheckoutSetupLeaveOption>.unmodifiable(
      results.take(maxResults),
    );
    _setupLeaveOptionsCache[cacheKey] = output;
    return output;
  }

  Map<CheckoutSetupFinishBand, CheckoutSetupLeaveOption> bestSetupBandOptions({
    required int startScore,
    required int dartsLeft,
    CheckoutRequirement checkoutRequirement = CheckoutRequirement.doubleOut,
    CheckoutPlayStyle playStyle = CheckoutPlayStyle.balanced,
    int leavePreference = 50,
    int outerBullPreference = 50,
    int bullPreference = 50,
    Set<int> preferredDoubles = const <int>{},
    Set<int> dislikedDoubles = const <int>{},
  }) {
    final sortedPreferred = preferredDoubles.toList()..sort();
    final sortedDisliked = dislikedDoubles.toList()..sort();
    final cacheKey = <Object>[
      startScore,
      dartsLeft,
      checkoutRequirement,
      playStyle,
      leavePreference,
      outerBullPreference,
      bullPreference,
      sortedPreferred,
      sortedDisliked,
    ].join('|');
    final cached = _setupBandOptionsCache[cacheKey];
    if (cached != null) {
      return cached;
    }

    final allOptions = setupLeaveOptions(
      startScore: startScore,
      dartsLeft: dartsLeft,
      checkoutRequirement: checkoutRequirement,
      playStyle: playStyle,
      leavePreference: leavePreference,
      outerBullPreference: outerBullPreference,
      bullPreference: bullPreference,
      maxResults: 1000,
      maxResultsPerNarrowCount: 20,
      preferredDoubles: preferredDoubles,
      dislikedDoubles: dislikedDoubles,
    );

    final result = <CheckoutSetupFinishBand, CheckoutSetupLeaveOption>{};
    final deepOption = _bestDeepSetupOption(
      allOptions,
      startScore: startScore,
      dartsLeft: dartsLeft,
      checkoutRequirement: checkoutRequirement,
      playStyle: playStyle,
      leavePreference: leavePreference,
      outerBullPreference: outerBullPreference,
      bullPreference: bullPreference,
      preferredDoubles: preferredDoubles,
      dislikedDoubles: dislikedDoubles,
    );
    if (deepOption != null) {
      result[CheckoutSetupFinishBand.deep] = deepOption;
    }
    final mediumOption = _bestSetupOptionForRange(
      allOptions,
      minRemaining: 100,
      maxRemaining: 130,
      startScore: startScore,
      dartsLeft: dartsLeft,
      checkoutRequirement: checkoutRequirement,
      playStyle: playStyle,
      leavePreference: leavePreference,
      outerBullPreference: outerBullPreference,
      bullPreference: bullPreference,
      preferredDoubles: preferredDoubles,
      dislikedDoubles: dislikedDoubles,
    );
    if (mediumOption != null) {
      result[CheckoutSetupFinishBand.medium] = mediumOption;
    }
    final justFinishOption = _bestSetupOptionForRange(
      allOptions,
      minRemaining: 160,
      maxRemaining: 170,
      startScore: startScore,
      dartsLeft: dartsLeft,
      checkoutRequirement: checkoutRequirement,
      playStyle: playStyle,
      leavePreference: leavePreference,
      outerBullPreference: outerBullPreference,
      bullPreference: bullPreference,
      preferredDoubles: preferredDoubles,
      dislikedDoubles: dislikedDoubles,
    );
    if (justFinishOption != null) {
      result[CheckoutSetupFinishBand.justFinish] = justFinishOption;
    }

    final output =
        Map<CheckoutSetupFinishBand, CheckoutSetupLeaveOption>.unmodifiable(
          result,
        );
    _setupBandOptionsCache[cacheKey] = output;
    return output;
  }

  List<DartThrowResult>? bestSetupFallbackRoute({
    required int startScore,
    required int dartsLeft,
    required CheckoutSetupFinishBand? targetBand,
    CheckoutRequirement checkoutRequirement = CheckoutRequirement.doubleOut,
    CheckoutPlayStyle playStyle = CheckoutPlayStyle.balanced,
    int leavePreference = 50,
    int outerBullPreference = 50,
    int bullPreference = 50,
    Set<int> preferredDoubles = const <int>{},
    Set<int> dislikedDoubles = const <int>{},
  }) {
    final sortedPreferred = preferredDoubles.toList()..sort();
    final sortedDisliked = dislikedDoubles.toList()..sort();
    final cacheKey = <Object>[
      startScore,
      dartsLeft,
      targetBand?.name ?? 'none',
      checkoutRequirement,
      playStyle,
      leavePreference,
      outerBullPreference,
      bullPreference,
      sortedPreferred,
      sortedDisliked,
    ].join('|');
    if (_setupFallbackRouteCache.containsKey(cacheKey)) {
      return _setupFallbackRouteCache[cacheKey];
    }
    if (!isValidSetupStartScore(startScore) || dartsLeft <= 0) {
      _setupFallbackRouteCache[cacheKey] = null;
      return null;
    }

    CheckoutSetupLeaveOption? best;
    switch (targetBand) {
      case CheckoutSetupFinishBand.deep:
        best = _bestDeepSetupOption(
          setupLeaveOptions(
            startScore: startScore,
            dartsLeft: dartsLeft,
            checkoutRequirement: checkoutRequirement,
            playStyle: playStyle,
            leavePreference: leavePreference,
            outerBullPreference: outerBullPreference,
            bullPreference: bullPreference,
            maxResults: 1000,
            maxResultsPerNarrowCount: 20,
            preferredDoubles: preferredDoubles,
            dislikedDoubles: dislikedDoubles,
          ),
          startScore: startScore,
          dartsLeft: dartsLeft,
          checkoutRequirement: checkoutRequirement,
          playStyle: playStyle,
          leavePreference: leavePreference,
          outerBullPreference: outerBullPreference,
          bullPreference: bullPreference,
          preferredDoubles: preferredDoubles,
          dislikedDoubles: dislikedDoubles,
        );
        break;
      case CheckoutSetupFinishBand.medium:
        best = _bestSetupOptionForRange(
          setupLeaveOptions(
            startScore: startScore,
            dartsLeft: dartsLeft,
            checkoutRequirement: checkoutRequirement,
            playStyle: playStyle,
            leavePreference: leavePreference,
            outerBullPreference: outerBullPreference,
            bullPreference: bullPreference,
            maxResults: 1000,
            maxResultsPerNarrowCount: 20,
            preferredDoubles: preferredDoubles,
            dislikedDoubles: dislikedDoubles,
          ),
          minRemaining: 100,
          maxRemaining: 130,
          startScore: startScore,
          dartsLeft: dartsLeft,
          checkoutRequirement: checkoutRequirement,
          playStyle: playStyle,
          leavePreference: leavePreference,
          outerBullPreference: outerBullPreference,
          bullPreference: bullPreference,
          preferredDoubles: preferredDoubles,
          dislikedDoubles: dislikedDoubles,
        );
        break;
      case CheckoutSetupFinishBand.justFinish:
        best = _bestSetupOptionForRange(
          setupLeaveOptions(
            startScore: startScore,
            dartsLeft: dartsLeft,
            checkoutRequirement: checkoutRequirement,
            playStyle: playStyle,
            leavePreference: leavePreference,
            outerBullPreference: outerBullPreference,
            bullPreference: bullPreference,
            maxResults: 1000,
            maxResultsPerNarrowCount: 20,
            preferredDoubles: preferredDoubles,
            dislikedDoubles: dislikedDoubles,
          ),
          minRemaining: 160,
          maxRemaining: 170,
          startScore: startScore,
          dartsLeft: dartsLeft,
          checkoutRequirement: checkoutRequirement,
          playStyle: playStyle,
          leavePreference: leavePreference,
          outerBullPreference: outerBullPreference,
          bullPreference: bullPreference,
          preferredDoubles: preferredDoubles,
          dislikedDoubles: dislikedDoubles,
        );
        break;
      case null:
        final options = setupLeaveOptions(
          startScore: startScore,
          dartsLeft: dartsLeft,
          checkoutRequirement: checkoutRequirement,
          playStyle: playStyle,
          leavePreference: leavePreference,
          outerBullPreference: outerBullPreference,
          bullPreference: bullPreference,
          maxResults: 1,
          maxResultsPerNarrowCount: 20,
          preferredDoubles: preferredDoubles,
          dislikedDoubles: dislikedDoubles,
        );
        best = options.isEmpty ? null : options.first;
        break;
    }

    final result = best?.setupRoute;
    _setupFallbackRouteCache[cacheKey] = result;
    return result;
  }

  List<List<DartThrowResult>> allRoutesToTargetRemaining({
    required int startScore,
    required int targetScore,
    required int dartsLeft,
  }) {
    final cacheKey = '$startScore|$targetScore|$dartsLeft';
    if (_targetRoutesCache.containsKey(cacheKey)) {
      return _targetRoutesCache[cacheKey]!;
    }

    if (startScore <= targetScore || targetScore < 0 || dartsLeft <= 0) {
      _targetRoutesCache[cacheKey] = const <List<DartThrowResult>>[];
      return _targetRoutesCache[cacheKey]!;
    }

    final routes = <List<DartThrowResult>>[];
    final seen = <String>{};

    void search(
      int remaining,
      int dartsRemaining,
      List<DartThrowResult> route,
    ) {
      if (dartsRemaining <= 0) {
        return;
      }

      for (final dartThrow in _allThrows) {
        if (dartThrow.scoredPoints <= 0) {
          continue;
        }

        final next = remaining - dartThrow.scoredPoints;
        if (next < targetScore) {
          continue;
        }

        route.add(dartThrow);
        if (next == targetScore) {
          final key = route.map((entry) => entry.label).join('-');
          if (seen.add(key)) {
            routes.add(List<DartThrowResult>.from(route));
          }
          route.removeLast();
          continue;
        }

        search(next, dartsRemaining - 1, route);
        route.removeLast();
      }
    }

    search(startScore, dartsLeft, <DartThrowResult>[]);
    _targetRoutesCache[cacheKey] = routes;
    return routes;
  }

  List<DartThrowResult>? bestRouteToTargetRemaining({
    required int startScore,
    required int targetScore,
    required int dartsLeft,
    CheckoutRequirement checkoutRequirement = CheckoutRequirement.doubleOut,
    CheckoutPlayStyle playStyle = CheckoutPlayStyle.balanced,
    bool twoDartOnly = false,
    bool avoidBull = false,
  }) {
    final cacheKey = <Object>[
      startScore,
      targetScore,
      dartsLeft,
      checkoutRequirement,
      playStyle,
      twoDartOnly,
      avoidBull,
    ].join('|');
    if (_targetRouteCache.containsKey(cacheKey)) {
      return _targetRouteCache[cacheKey];
    }

    final routes =
        allRoutesToTargetRemaining(
          startScore: startScore,
          targetScore: targetScore,
          dartsLeft: dartsLeft,
        ).where((route) {
          if (twoDartOnly && route.length != 2) {
            return false;
          }
          if (avoidBull &&
              route.any((entry) => entry.isBull || entry.label == '25')) {
            return false;
          }
          return true;
        }).toList();

    if (routes.isEmpty) {
      _targetRouteCache[cacheKey] = null;
      return null;
    }

    routes.sort(
      (a, b) =>
          scoreRouteToTargetRemaining(
            route: b,
            startScore: startScore,
            targetScore: targetScore,
            dartsLeft: dartsLeft,
            checkoutRequirement: checkoutRequirement,
            playStyle: playStyle,
          ).compareTo(
            scoreRouteToTargetRemaining(
              route: a,
              startScore: startScore,
              targetScore: targetScore,
              dartsLeft: dartsLeft,
              checkoutRequirement: checkoutRequirement,
              playStyle: playStyle,
            ),
          ),
    );

    final best = routes.first;
    _targetRouteCache[cacheKey] = best;
    return best;
  }

  List<List<DartThrowResult>> allCheckoutRoutes({
    required int score,
    required int dartsLeft,
    CheckoutRequirement checkoutRequirement = CheckoutRequirement.doubleOut,
    CheckoutPlayStyle playStyle = CheckoutPlayStyle.balanced,
  }) {
    final cacheKey = '$score|$dartsLeft|$checkoutRequirement|$playStyle';
    if (_checkoutRoutesCache.containsKey(cacheKey)) {
      return _checkoutRoutesCache[cacheKey]!;
    }

    final finishes = <List<DartThrowResult>>[];
    final seen = <String>{};

    void search(
      int remaining,
      int dartsRemaining,
      List<DartThrowResult> route,
    ) {
      if (dartsRemaining <= 0) {
        return;
      }

      for (final dartThrow in _allThrows) {
        if (dartThrow.scoredPoints <= 0) {
          continue;
        }

        final next = remaining - dartThrow.scoredPoints;
        if (next < 0 || _isDeadScoreForCheckout(next, checkoutRequirement)) {
          continue;
        }

        route.add(dartThrow);
        if (next == 0) {
          if (!dartThrow.matchesCheckoutRequirement(checkoutRequirement)) {
            route.removeLast();
            continue;
          }
          final key = route.map((entry) => entry.label).join('-');
          if (seen.add(key)) {
            finishes.add(List<DartThrowResult>.from(route));
          }
          route.removeLast();
          continue;
        }

        search(next, dartsRemaining - 1, route);
        route.removeLast();
      }
    }

    search(score, dartsLeft, <DartThrowResult>[]);
    _checkoutRoutesCache[cacheKey] = finishes;
    return finishes;
  }

  List<DartThrowResult>? bestFinishRoute({
    required int score,
    required int dartsLeft,
    CheckoutRequirement checkoutRequirement = CheckoutRequirement.doubleOut,
    CheckoutPlayStyle playStyle = CheckoutPlayStyle.balanced,
    int outerBullPreference = 50,
    int bullPreference = 50,
  }) {
    final cacheKey =
        '$score|$dartsLeft|$checkoutRequirement|$playStyle|$outerBullPreference|$bullPreference';
    if (_finishRouteCache.containsKey(cacheKey)) {
      return _finishRouteCache[cacheKey];
    }

    final routes = allCheckoutRoutes(
      score: score,
      dartsLeft: dartsLeft,
      checkoutRequirement: checkoutRequirement,
      playStyle: playStyle,
    );
    if (routes.isEmpty) {
      _finishRouteCache[cacheKey] = null;
      return null;
    }

    routes.sort(
      (a, b) =>
          scoreRoute(
            route: b,
            startScore: score,
            totalDarts: dartsLeft,
            checkoutRequirement: checkoutRequirement,
            playStyle: playStyle,
            outerBullPreference: outerBullPreference,
            bullPreference: bullPreference,
          ).compareTo(
            scoreRoute(
              route: a,
              startScore: score,
              totalDarts: dartsLeft,
              checkoutRequirement: checkoutRequirement,
              playStyle: playStyle,
              outerBullPreference: outerBullPreference,
              bullPreference: bullPreference,
            ),
          ),
    );
    final best = routes.first;
    _finishRouteCache[cacheKey] = best;
    return best;
  }

  List<DartThrowResult>? bestFinishRouteForNarrowFieldCount({
    required int score,
    required int dartsLeft,
    required int narrowFieldCount,
    CheckoutRequirement checkoutRequirement = CheckoutRequirement.doubleOut,
    CheckoutPlayStyle playStyle = CheckoutPlayStyle.balanced,
    int outerBullPreference = 50,
    int bullPreference = 50,
  }) {
    final routes =
        allCheckoutRoutes(
              score: score,
              dartsLeft: dartsLeft,
              checkoutRequirement: checkoutRequirement,
              playStyle: playStyle,
            )
            .where(
              (route) => route.where(isNarrowField).length == narrowFieldCount,
            )
            .toList();

    if (routes.isEmpty) {
      return null;
    }

    routes.sort(
      (a, b) =>
          scoreRoute(
            route: b,
            startScore: score,
            totalDarts: dartsLeft,
            checkoutRequirement: checkoutRequirement,
            playStyle: playStyle,
            outerBullPreference: outerBullPreference,
            bullPreference: bullPreference,
          ).compareTo(
            scoreRoute(
              route: a,
              startScore: score,
              totalDarts: dartsLeft,
              checkoutRequirement: checkoutRequirement,
              playStyle: playStyle,
              outerBullPreference: outerBullPreference,
              bullPreference: bullPreference,
            ),
          ),
    );

    return routes.first;
  }

  List<DartThrowResult>? bestFinishRouteForFinishType({
    required int score,
    required int dartsLeft,
    required bool Function(DartThrowResult lastThrow) matcher,
    required String matcherKey,
    CheckoutRequirement checkoutRequirement = CheckoutRequirement.doubleOut,
    CheckoutPlayStyle playStyle = CheckoutPlayStyle.balanced,
    int outerBullPreference = 50,
    int bullPreference = 50,
  }) {
    final cacheKey = <Object>[
      score,
      dartsLeft,
      matcherKey,
      checkoutRequirement,
      playStyle,
      outerBullPreference,
      bullPreference,
    ].join('|');
    if (_finishRouteByTypeCache.containsKey(cacheKey)) {
      return _finishRouteByTypeCache[cacheKey];
    }

    List<DartThrowResult>? best;
    var bestScore = -999999999;

    void search(
      int remaining,
      int dartsRemaining,
      List<DartThrowResult> route,
    ) {
      if (dartsRemaining <= 0) {
        return;
      }

      for (final dartThrow in _allThrows) {
        if (dartThrow.scoredPoints <= 0) {
          continue;
        }

        final next = remaining - dartThrow.scoredPoints;
        if (next < 0 || _isDeadScoreForCheckout(next, checkoutRequirement)) {
          continue;
        }

        route.add(dartThrow);
        if (next == 0) {
          if (!dartThrow.matchesCheckoutRequirement(checkoutRequirement) ||
              !matcher(dartThrow)) {
            route.removeLast();
            continue;
          }
          final candidateScore = scoreRoute(
            route: route,
            startScore: score,
            totalDarts: dartsLeft,
            checkoutRequirement: checkoutRequirement,
            playStyle: playStyle,
            outerBullPreference: outerBullPreference,
            bullPreference: bullPreference,
          );
          if (candidateScore > bestScore) {
            bestScore = candidateScore;
            best = List<DartThrowResult>.from(route);
          }
          route.removeLast();
          continue;
        }

        search(next, dartsRemaining - 1, route);
        route.removeLast();
      }
    }

    search(score, dartsLeft, const <DartThrowResult>[]);
    _finishRouteByTypeCache[cacheKey] = best;
    return best;
  }

  List<CheckoutSetupLeaveOption> topSetupLeavesForNarrowFieldCount({
    required int startScore,
    required int dartsLeft,
    required int narrowFieldCount,
    CheckoutRequirement checkoutRequirement = CheckoutRequirement.doubleOut,
    CheckoutPlayStyle playStyle = CheckoutPlayStyle.balanced,
    int leavePreference = 50,
    int outerBullPreference = 50,
    int bullPreference = 50,
    int maxResults = 3,
  }) {
    final cacheKey = <Object>[
      startScore,
      dartsLeft,
      narrowFieldCount,
      checkoutRequirement,
      playStyle,
      leavePreference,
      outerBullPreference,
      bullPreference,
      maxResults,
    ].join('|');
    final cached = _topSetupLeavesCache[cacheKey];
    if (cached != null) {
      return cached;
    }
    if (startScore <= 1 || dartsLeft <= 0) {
      return const <CheckoutSetupLeaveOption>[];
    }

    final candidates = <CheckoutSetupLeaveOption>[];
    final candidateLimit = (maxResults * 6).clamp(24, 96);
    final seen = <String>{};

    void search(
      int remaining,
      int dartsRemaining,
      List<DartThrowResult> route,
      int narrowFieldsUsed,
    ) {
      if (dartsRemaining <= 0 || narrowFieldsUsed > narrowFieldCount) {
        return;
      }

      for (final dartThrow in _allThrows) {
        if (dartThrow.scoredPoints <= 0) {
          continue;
        }

        final next = remaining - dartThrow.scoredPoints;
        if (next <= 1) {
          continue;
        }

        final nextNarrowFields =
            narrowFieldsUsed + (isNarrowField(dartThrow) ? 1 : 0);
        if (nextNarrowFields > narrowFieldCount) {
          continue;
        }

        route.add(dartThrow);
        final finishRoute = bestFinishRoute(
          score: next,
          dartsLeft: 3,
          checkoutRequirement: checkoutRequirement,
          playStyle: playStyle,
          outerBullPreference: outerBullPreference,
          bullPreference: bullPreference,
        );

        if (finishRoute != null && nextNarrowFields == narrowFieldCount) {
          final routeKey = route.map((entry) => entry.label).join('-');
          final key = '$next|$routeKey';
          if (seen.add(key)) {
            final breakdown = setupLeaveScoreBreakdown(
              setupRoute: route,
              startScore: startScore,
              remainingScore: next,
              finishRoute: finishRoute,
              dartsLeft: dartsLeft,
              checkoutRequirement: checkoutRequirement,
              playStyle: playStyle,
              leavePreference: leavePreference,
              outerBullPreference: outerBullPreference,
              bullPreference: bullPreference,
            );
            final candidate = CheckoutSetupLeaveOption(
              setupRoute: List<DartThrowResult>.unmodifiable(route),
              remainingScore: next,
              finishRoute: finishRoute,
              score: breakdown.totalScore,
              breakdown: breakdown,
            );
            candidates.add(candidate);
            if (candidates.length > candidateLimit * 2) {
              candidates.sort((a, b) => b.score.compareTo(a.score));
              candidates.removeRange(candidateLimit, candidates.length);
            }
          }
        }

        search(next, dartsRemaining - 1, route, nextNarrowFields);
        route.removeLast();
      }
    }

    search(startScore, dartsLeft, <DartThrowResult>[], 0);
    candidates.sort((a, b) => b.score.compareTo(a.score));
    if (candidates.length > candidateLimit) {
      candidates.removeRange(candidateLimit, candidates.length);
    }
    final results = List<CheckoutSetupLeaveOption>.unmodifiable(
      candidates.take(maxResults),
    );
    _topSetupLeavesCache[cacheKey] = results;
    return results;
  }

  CheckoutSetupLeaveOption? bestSetupLeaveForNarrowFieldCount({
    required int startScore,
    required int dartsLeft,
    required int narrowFieldCount,
    CheckoutRequirement checkoutRequirement = CheckoutRequirement.doubleOut,
    CheckoutPlayStyle playStyle = CheckoutPlayStyle.balanced,
    int leavePreference = 50,
    int outerBullPreference = 50,
    int bullPreference = 50,
  }) {
    final results = topSetupLeavesForNarrowFieldCount(
      startScore: startScore,
      dartsLeft: dartsLeft,
      narrowFieldCount: narrowFieldCount,
      checkoutRequirement: checkoutRequirement,
      playStyle: playStyle,
      leavePreference: leavePreference,
      outerBullPreference: outerBullPreference,
      bullPreference: bullPreference,
      maxResults: 1,
    );
    return results.isEmpty ? null : results.first;
  }

  CheckoutSetupLeaveOption? _bestDeepSetupOption(
    List<CheckoutSetupLeaveOption> options, {
    required int startScore,
    required int dartsLeft,
    required CheckoutRequirement checkoutRequirement,
    required CheckoutPlayStyle playStyle,
    required int leavePreference,
    required int outerBullPreference,
    required int bullPreference,
    required Set<int> preferredDoubles,
    required Set<int> dislikedDoubles,
  }) {
    CheckoutSetupLeaveOption? bestDirectDouble;
    for (final remaining in <int>[
      32,
      40,
      36,
      24,
      20,
      16,
      8,
      12,
      28,
      18,
      14,
      10,
      6,
      4,
      2,
      50,
      26,
      22,
      38,
      34,
      30,
    ]) {
      if (remaining >= startScore) {
        continue;
      }
      final routes = allRoutesToTargetRemaining(
        startScore: startScore,
        targetScore: remaining,
        dartsLeft: dartsLeft,
      );
      for (final route in routes) {
        if (!isAllowedSetupRoute(route)) {
          continue;
        }
        final finishRoute = bestFinishRoute(
          score: remaining,
          dartsLeft: 3,
          checkoutRequirement: checkoutRequirement,
          playStyle: playStyle,
          outerBullPreference: outerBullPreference,
          bullPreference: bullPreference,
        );
        if (finishRoute == null || finishRoute.isEmpty) {
          continue;
        }
        final breakdown = setupLeaveScoreBreakdown(
          setupRoute: route,
          startScore: startScore,
          remainingScore: remaining,
          finishRoute: finishRoute,
          dartsLeft: dartsLeft,
          checkoutRequirement: checkoutRequirement,
          playStyle: playStyle,
          leavePreference: leavePreference,
          outerBullPreference: outerBullPreference,
          bullPreference: bullPreference,
        );
        final option = CheckoutSetupLeaveOption(
          setupRoute: route,
          remainingScore: remaining,
          finishRoute: finishRoute,
          score: breakdown.totalScore,
          breakdown: breakdown,
        );
        if (bestDirectDouble == null ||
            _compareDeepDirectDoubleCandidates(
                  option,
                  bestDirectDouble,
                  startScore: startScore,
                  dartsLeft: dartsLeft,
                  checkoutRequirement: checkoutRequirement,
                  playStyle: playStyle,
                  outerBullPreference: outerBullPreference,
                  bullPreference: bullPreference,
                  preferredDoubles: preferredDoubles,
                  dislikedDoubles: dislikedDoubles,
                ) <
                0) {
          bestDirectDouble = option;
        }
      }
    }
    if (bestDirectDouble != null) {
      return bestDirectDouble;
    }

    final deepCandidates = options
        .where((entry) => entry.remainingScore <= 79)
        .toList(growable: false);
    final directDoubleCandidates = deepCandidates
        .where((entry) => _isDirectDoubleLeave(entry.remainingScore))
        .toList(growable: false);
    if (directDoubleCandidates.isNotEmpty) {
      directDoubleCandidates.sort(
        (a, b) => _compareDeepDirectDoubleCandidates(
          a,
          b,
          startScore: startScore,
          dartsLeft: dartsLeft,
          checkoutRequirement: checkoutRequirement,
          playStyle: playStyle,
          outerBullPreference: outerBullPreference,
          bullPreference: bullPreference,
          preferredDoubles: preferredDoubles,
          dislikedDoubles: dislikedDoubles,
        ),
      );
      return directDoubleCandidates.first;
    }

    final finishUpTo99 = options
        .where((entry) => entry.remainingScore <= 99)
        .toList(growable: false);
    if (finishUpTo99.isEmpty) {
      return null;
    }
    finishUpTo99.sort((a, b) {
      final intentCompare =
          _deepFirstDartIntentValue(
            b,
            startScore: startScore,
            dartsLeft: dartsLeft,
            checkoutRequirement: checkoutRequirement,
            playStyle: playStyle,
            outerBullPreference: outerBullPreference,
            bullPreference: bullPreference,
          ).compareTo(
            _deepFirstDartIntentValue(
              a,
              startScore: startScore,
              dartsLeft: dartsLeft,
              checkoutRequirement: checkoutRequirement,
              playStyle: playStyle,
              outerBullPreference: outerBullPreference,
              bullPreference: bullPreference,
            ),
          );
      if (intentCompare != 0) {
        return intentCompare;
      }
      return setupLeaveEffectiveScore(
        b,
        preferredDoubles: preferredDoubles,
        dislikedDoubles: dislikedDoubles,
      ).compareTo(
        setupLeaveEffectiveScore(
          a,
          preferredDoubles: preferredDoubles,
          dislikedDoubles: dislikedDoubles,
        ),
      );
    });
    return finishUpTo99.first;
  }

  CheckoutSetupLeaveOption? _bestSetupOptionForRange(
    List<CheckoutSetupLeaveOption> options, {
    required int minRemaining,
    required int maxRemaining,
    required int startScore,
    required int dartsLeft,
    required CheckoutRequirement checkoutRequirement,
    required CheckoutPlayStyle playStyle,
    required int leavePreference,
    required int outerBullPreference,
    required int bullPreference,
    required Set<int> preferredDoubles,
    required Set<int> dislikedDoubles,
  }) {
    final fromExisting = options
        .where(
          (entry) =>
              entry.remainingScore >= minRemaining &&
              entry.remainingScore <= maxRemaining,
        )
        .toList(growable: false);
    if (fromExisting.isNotEmpty) {
      final sorted = fromExisting.toList()
        ..sort(
          (a, b) =>
              setupLeaveEffectiveScore(
                b,
                preferredDoubles: preferredDoubles,
                dislikedDoubles: dislikedDoubles,
              ).compareTo(
                setupLeaveEffectiveScore(
                  a,
                  preferredDoubles: preferredDoubles,
                  dislikedDoubles: dislikedDoubles,
                ),
              ),
        );
      return sorted.first;
    }

    CheckoutSetupLeaveOption? best;
    for (
      var remaining = minRemaining;
      remaining <= maxRemaining;
      remaining += 1
    ) {
      if (remaining >= startScore) {
        continue;
      }
      final routes = allRoutesToTargetRemaining(
        startScore: startScore,
        targetScore: remaining,
        dartsLeft: dartsLeft,
      );
      for (final route in routes) {
        if (!isAllowedSetupRoute(route)) {
          continue;
        }
        final finishRoute = bestFinishRoute(
          score: remaining,
          dartsLeft: 3,
          checkoutRequirement: checkoutRequirement,
          playStyle: playStyle,
          outerBullPreference: outerBullPreference,
          bullPreference: bullPreference,
        );
        if (finishRoute == null || finishRoute.isEmpty) {
          continue;
        }
        final breakdown = setupLeaveScoreBreakdown(
          setupRoute: route,
          startScore: startScore,
          remainingScore: remaining,
          finishRoute: finishRoute,
          dartsLeft: dartsLeft,
          checkoutRequirement: checkoutRequirement,
          playStyle: playStyle,
          leavePreference: leavePreference,
          outerBullPreference: outerBullPreference,
          bullPreference: bullPreference,
        );
        final option = CheckoutSetupLeaveOption(
          setupRoute: route,
          remainingScore: remaining,
          finishRoute: finishRoute,
          score: breakdown.totalScore,
          breakdown: breakdown,
        );
        if (best == null ||
            setupLeaveEffectiveScore(
                  option,
                  preferredDoubles: preferredDoubles,
                  dislikedDoubles: dislikedDoubles,
                ) >
                setupLeaveEffectiveScore(
                  best,
                  preferredDoubles: preferredDoubles,
                  dislikedDoubles: dislikedDoubles,
                )) {
          best = option;
        }
      }
    }
    return best;
  }

  int _compareDeepDirectDoubleCandidates(
    CheckoutSetupLeaveOption a,
    CheckoutSetupLeaveOption b, {
    required int startScore,
    required int dartsLeft,
    required CheckoutRequirement checkoutRequirement,
    required CheckoutPlayStyle playStyle,
    required int outerBullPreference,
    required int bullPreference,
    required Set<int> preferredDoubles,
    required Set<int> dislikedDoubles,
  }) {
    final aGoodDouble = _isGoodDeepDoubleLeave(a.remainingScore);
    final bGoodDouble = _isGoodDeepDoubleLeave(b.remainingScore);
    final doubleCompare = _deepDirectDoubleValue(
      b.remainingScore,
    ).compareTo(_deepDirectDoubleValue(a.remainingScore));
    if (doubleCompare != 0) {
      return doubleCompare;
    }
    final intentCompare =
        _deepFirstDartIntentValue(
          b,
          startScore: startScore,
          dartsLeft: dartsLeft,
          checkoutRequirement: checkoutRequirement,
          playStyle: playStyle,
          outerBullPreference: outerBullPreference,
          bullPreference: bullPreference,
        ).compareTo(
          _deepFirstDartIntentValue(
            a,
            startScore: startScore,
            dartsLeft: dartsLeft,
            checkoutRequirement: checkoutRequirement,
            playStyle: playStyle,
            outerBullPreference: outerBullPreference,
            bullPreference: bullPreference,
          ),
        );
    if (intentCompare != 0) {
      return intentCompare;
    }
    if (aGoodDouble && bGoodDouble) {
      final pathCompare = b.breakdown.routeGuidance.compareTo(
        a.breakdown.routeGuidance,
      );
      if (pathCompare != 0) {
        return pathCompare;
      }
    }
    return setupLeaveEffectiveScore(
      b,
      preferredDoubles: preferredDoubles,
      dislikedDoubles: dislikedDoubles,
    ).compareTo(
      setupLeaveEffectiveScore(
        a,
        preferredDoubles: preferredDoubles,
        dislikedDoubles: dislikedDoubles,
      ),
    );
  }

  int _deepDirectDoubleValue(int remainingScore) {
    if (remainingScore == 50) {
      return 40;
    }
    if (remainingScore > 1 && remainingScore <= 40 && remainingScore.isEven) {
      return _isGoodDeepDoubleLeave(remainingScore) ? 100 : 20;
    }
    return 0;
  }

  bool _isGoodDeepDoubleLeave(int remainingScore) {
    if (remainingScore <= 1 || remainingScore > 40 || !remainingScore.isEven) {
      return false;
    }
    final doubleValue = remainingScore ~/ 2;
    var twos = 0;
    var value = doubleValue;
    while (value > 0 && value.isEven) {
      twos += 1;
      value ~/= 2;
    }
    return twos >= 3;
  }

  int _deepFirstDartIntentValue(
    CheckoutSetupLeaveOption option, {
    required int startScore,
    required int dartsLeft,
    required CheckoutRequirement checkoutRequirement,
    required CheckoutPlayStyle playStyle,
    required int outerBullPreference,
    required int bullPreference,
  }) {
    if (option.setupRoute.isEmpty || dartsLeft <= 1) {
      return 0;
    }
    final first = option.setupRoute.first;
    if (first.isTriple) {
      final fallbackRemaining = startScore - first.baseValue;
      final fallbackFinish = bestFinishRoute(
        score: fallbackRemaining,
        dartsLeft: dartsLeft - 1,
        checkoutRequirement: checkoutRequirement,
        playStyle: playStyle,
        outerBullPreference: outerBullPreference,
        bullPreference: bullPreference,
      );
      if (fallbackFinish != null && fallbackFinish.isNotEmpty) {
        return 220;
      }
      return 80;
    }
    if (first.isBull) {
      final fallbackRemaining = startScore - 25;
      final fallbackFinish = bestFinishRoute(
        score: fallbackRemaining,
        dartsLeft: dartsLeft - 1,
        checkoutRequirement: checkoutRequirement,
        playStyle: playStyle,
        outerBullPreference: outerBullPreference,
        bullPreference: bullPreference,
      );
      if (fallbackFinish != null && fallbackFinish.isNotEmpty) {
        return 180;
      }
      return 40;
    }
    if (first.isDouble && !first.isBull) {
      return -180;
    }
    if (!isNarrowField(first) && first.baseValue >= 15) {
      return -120;
    }
    return 0;
  }

  CheckoutSetupFinishBand? classifySetupFinishBand(int remainingScore) {
    if (remainingScore <= 79) {
      return CheckoutSetupFinishBand.deep;
    }
    if (remainingScore >= 100 && remainingScore <= 130) {
      return CheckoutSetupFinishBand.medium;
    }
    if (remainingScore >= 160 && remainingScore <= 170) {
      return CheckoutSetupFinishBand.justFinish;
    }
    return null;
  }

  bool _isDirectDoubleLeave(int remainingScore) {
    return remainingScore == 50 ||
        (remainingScore > 1 && remainingScore <= 40 && remainingScore.isEven);
  }

  CheckoutContinuationPlan? bestContinuationPlan({
    required int score,
    required int dartsLeft,
    CheckoutRequirement checkoutRequirement = CheckoutRequirement.doubleOut,
    CheckoutPlayStyle playStyle = CheckoutPlayStyle.balanced,
    int outerBullPreference = 50,
    int bullPreference = 50,
  }) {
    final cacheKey =
        '$score|$dartsLeft|$checkoutRequirement|$playStyle|$outerBullPreference|$bullPreference';
    if (_continuationPlanCache.containsKey(cacheKey)) {
      return _continuationPlanCache[cacheKey];
    }

    final exactRoute = bestFinishRoute(
      score: score,
      dartsLeft: dartsLeft,
      checkoutRequirement: checkoutRequirement,
      playStyle: playStyle,
      outerBullPreference: outerBullPreference,
      bullPreference: bullPreference,
    );
    if (exactRoute != null && exactRoute.isNotEmpty) {
      final exactPlan = CheckoutContinuationPlan(
        throws: exactRoute,
        immediateFinish: true,
        score:
            3000 +
            simpleRouteScore(
              exactRoute,
              playStyle: playStyle,
              outerBullPreference: outerBullPreference,
              bullPreference: bullPreference,
            ),
      );
      _continuationPlanCache[cacheKey] = exactPlan;
      return exactPlan;
    }

    if (dartsLeft <= 0) {
      _continuationPlanCache[cacheKey] = null;
      return null;
    }

    CheckoutContinuationPlan? best;
    for (final dartThrow in _allThrows) {
      if (dartThrow.scoredPoints <= 0) {
        continue;
      }

      final next = score - dartThrow.scoredPoints;
      if (next < 0 || _isDeadScoreForCheckout(next, checkoutRequirement)) {
        continue;
      }

      if (dartsLeft == 1) {
        final nextVisitRoute = bestFinishRoute(
          score: next,
          dartsLeft: 3,
          checkoutRequirement: checkoutRequirement,
          playStyle: playStyle,
          outerBullPreference: outerBullPreference,
          bullPreference: bullPreference,
        );
        if (nextVisitRoute == null || nextVisitRoute.isEmpty) {
          continue;
        }

        final candidate = CheckoutContinuationPlan(
          throws: <DartThrowResult>[dartThrow, ...nextVisitRoute],
          immediateFinish: false,
          score:
              1400 +
              simpleRouteScore(
                nextVisitRoute,
                playStyle: playStyle,
                outerBullPreference: outerBullPreference,
                bullPreference: bullPreference,
              ) +
              setupThrowBias(dartThrow),
        );
        if (best == null || candidate.score > best.score) {
          best = candidate;
        }
        continue;
      }

      final tail = bestContinuationPlan(
        score: next,
        dartsLeft: dartsLeft - 1,
        checkoutRequirement: checkoutRequirement,
        playStyle: playStyle,
        outerBullPreference: outerBullPreference,
        bullPreference: bullPreference,
      );
      if (tail == null || tail.throws.isEmpty) {
        continue;
      }

      final candidate = CheckoutContinuationPlan(
        throws: <DartThrowResult>[dartThrow, ...tail.throws],
        immediateFinish: false,
        score: tail.score + setupThrowBias(dartThrow),
      );
      if (best == null || candidate.score > best.score) {
        best = candidate;
      }
    }

    _continuationPlanCache[cacheKey] = best;
    return best;
  }

  int scoreRoute({
    required List<DartThrowResult> route,
    required int startScore,
    required int totalDarts,
    CheckoutRequirement checkoutRequirement = CheckoutRequirement.doubleOut,
    CheckoutPlayStyle playStyle = CheckoutPlayStyle.balanced,
    int outerBullPreference = 50,
    int bullPreference = 50,
  }) {
    final dartsUsedScore = 1280 - (route.length * 140);
    final twoDartCheckoutBonus = 0;
    final smallCheckoutSingleDoubleBonus = _smallCheckoutSingleDoubleBonus(
      route: route,
      startScore: startScore,
      checkoutRequirement: checkoutRequirement,
    );
    final narrowFieldPenalty = _narrowFieldPenalty(route, defaultPenalty: 150);
    final outerBullPenalty =
        route.where((entry) => entry.label == '25').length *
        _outerBullPenaltyValue(0, outerBullPreference);
    final finalBullPenalty = route.isNotEmpty && route.last.isBull
        ? _bullPenaltyValue(65, bullPreference, scale: 1)
        : 0;
    final endingDoubleDoubleBonus = doubleDoubleEndingBonus(route);
    final goodDoubleBonus = doublePreference(route.last);
    final continuityBonus = continuityScore(route);
    final comfortBonus =
        comfortScore(route) +
        _smallTripleOver100Penalty(route: route, startScore: startScore) +
        _checkoutFallbackComfortRelief(
          route: route,
          startScore: startScore,
          totalDarts: totalDarts,
          checkoutRequirement: checkoutRequirement,
          playStyle: playStyle,
          outerBullPreference: outerBullPreference,
          bullPreference: bullPreference,
        );
    final robustnessAnalysis = _robustnessDetails(
      route: route,
      startScore: startScore,
      totalDarts: totalDarts,
      checkoutRequirement: checkoutRequirement,
      playStyle: playStyle,
      outerBullPreference: outerBullPreference,
      bullPreference: bullPreference,
    );
    final singleOr25DoubleBonus = singleOr25DoubleAccessBonus(
      route: route,
      startScore: startScore,
    );
    final robustnessBonus = robustnessAnalysis.total + singleOr25DoubleBonus;
    final styleBonus = playStyleRouteAdjustment(
      route: route,
      startScore: startScore,
      totalDarts: totalDarts,
      checkoutRequirement: checkoutRequirement,
      playStyle: playStyle,
      comfortBonus: comfortBonus,
      robustnessBonus: robustnessBonus,
      narrowFieldPenalty: narrowFieldPenalty,
    );

    return dartsUsedScore +
        twoDartCheckoutBonus +
        smallCheckoutSingleDoubleBonus +
        endingDoubleDoubleBonus +
        goodDoubleBonus +
        comfortBonus +
        continuityBonus +
        styleBonus +
        robustnessBonus -
        narrowFieldPenalty -
        outerBullPenalty -
        finalBullPenalty;
  }

  CheckoutRouteScoreBreakdown routeScoreBreakdown({
    required List<DartThrowResult> route,
    required int startScore,
    required int totalDarts,
    CheckoutRequirement checkoutRequirement = CheckoutRequirement.doubleOut,
    CheckoutPlayStyle playStyle = CheckoutPlayStyle.balanced,
    int outerBullPreference = 50,
    int bullPreference = 50,
  }) {
    final cacheKey = <Object>[
      route.map((entry) => entry.label).join('-'),
      startScore,
      totalDarts,
      checkoutRequirement,
      playStyle,
      outerBullPreference,
      bullPreference,
    ].join('|');
    final cached = _routeScoreBreakdownCache[cacheKey];
    if (cached != null) {
      return cached;
    }
    final dartsUsedScore = 1280 - (route.length * 140);
    final twoDartCheckoutBonus = 0;
    final smallCheckoutSingleDoubleBonus = _smallCheckoutSingleDoubleBonus(
      route: route,
      startScore: startScore,
      checkoutRequirement: checkoutRequirement,
    );
    final narrowFieldPenalty = _narrowFieldPenalty(route, defaultPenalty: 150);
    final finalBullPenalty = route.isNotEmpty && route.last.isBull
        ? _bullPenaltyValue(65, bullPreference, scale: 1)
        : 0;
    final outerBullPenalty =
        route.where((entry) => entry.label == '25').length *
        _outerBullPenaltyValue(0, outerBullPreference);
    final endingDoubleDoubleBonus = doubleDoubleEndingBonus(route);

    final robustnessAnalysis = _robustnessDetails(
      route: route,
      startScore: startScore,
      totalDarts: totalDarts,
      checkoutRequirement: checkoutRequirement,
      playStyle: playStyle,
      outerBullPreference: outerBullPreference,
      bullPreference: bullPreference,
    );

    final comfortRelief = _checkoutFallbackComfortRelief(
      route: route,
      startScore: startScore,
      totalDarts: totalDarts,
      checkoutRequirement: checkoutRequirement,
      playStyle: playStyle,
      outerBullPreference: outerBullPreference,
      bullPreference: bullPreference,
    );

    final breakdown = CheckoutRouteScoreBreakdown(
      dartPathScore:
          dartsUsedScore +
          twoDartCheckoutBonus +
          smallCheckoutSingleDoubleBonus,
      comfort:
          comfortScore(route) +
          _smallTripleOver100Penalty(route: route, startScore: startScore) +
          comfortRelief,
      robustness:
          robustnessAnalysis.total +
          singleOr25DoubleAccessBonus(route: route, startScore: startScore),
      doubleQuality:
          (route.isEmpty ? 0 : doublePreference(route.last)) +
          endingDoubleDoubleBonus,
      narrowFieldPenalty: narrowFieldPenalty,
      bullPenalty: finalBullPenalty + outerBullPenalty,
      segmentFlow: continuityScore(route),
      dartPathDetails: _dartPathDetails(
        routeLength: route.length,
        baseScore: dartsUsedScore + smallCheckoutSingleDoubleBonus,
        twoDartBonus: twoDartCheckoutBonus,
      ),
      comfortDetails: _comfortDetails(
        route,
        startScore: startScore,
        totalDarts: totalDarts,
        checkoutRequirement: checkoutRequirement,
        playStyle: playStyle,
        outerBullPreference: outerBullPreference,
        bullPreference: bullPreference,
      ),
      robustnessDetails: <String>[
        ...robustnessAnalysis.details,
        if (singleOr25DoubleAccessBonus(route: route, startScore: startScore) >
            0)
          'Single/25-Weg auf Doppel oder Bull erreichbar: +${singleOr25DoubleAccessBonus(route: route, startScore: startScore)}',
      ],
      doubleQualityDetails: <String>[
        ..._doubleDetails(route.isEmpty ? null : route.last),
        if (endingDoubleDoubleBonus > 0)
          'Double-Double-Endbonus: +$endingDoubleDoubleBonus',
      ],
      narrowFieldDetails: _narrowFieldDetails(
        route: route,
        penalty: narrowFieldPenalty,
      ),
      bullPenaltyDetails: _bullPenaltyDetails(
        route: route,
        finalBullPenalty: finalBullPenalty,
        outerBullPenalty: outerBullPenalty,
      ),
      segmentFlowDetails: _segmentFlowDetails(route),
    );
    _routeScoreBreakdownCache[cacheKey] = breakdown;
    return breakdown;
  }

  int simpleRouteScore(
    List<DartThrowResult> route, {
    CheckoutPlayStyle playStyle = CheckoutPlayStyle.balanced,
    int outerBullPreference = 50,
    int bullPreference = 50,
  }) {
    final dartsUsedScore = 1180 - (route.length * 135);
    final twoDartCheckoutBonus = 0;
    final smallCheckoutSingleDoubleBonus = _smallCheckoutSingleDoubleBonus(
      route: route,
      startScore: route.fold<int>(0, (sum, entry) => sum + entry.scoredPoints),
      checkoutRequirement: CheckoutRequirement.doubleOut,
    );
    final narrowFieldPenalty = _narrowFieldPenalty(route, defaultPenalty: 120);
    final outerBullPenalty =
        route.where((entry) => entry.label == '25').length *
        _outerBullPenaltyValue(0, outerBullPreference);
    final finalBullPenalty = route.isNotEmpty && route.last.isBull
        ? _bullPenaltyValue(65, bullPreference, scale: 1)
        : 0;
    final endingDoubleDoubleBonus = doubleDoubleEndingBonus(route);

    final baseScore =
        dartsUsedScore +
        twoDartCheckoutBonus +
        smallCheckoutSingleDoubleBonus +
        endingDoubleDoubleBonus +
        doublePreference(route.last) +
        comfortScore(route) +
        continuityScore(route) -
        narrowFieldPenalty -
        outerBullPenalty -
        finalBullPenalty;

    switch (playStyle) {
      case CheckoutPlayStyle.safe:
        return baseScore +
            (comfortScore(route) ~/ 3) -
            (route.length == 2 ? 20 : 0);
      case CheckoutPlayStyle.aggressive:
        return baseScore + (route.length == 2 ? 60 : 0);
      case CheckoutPlayStyle.balanced:
        return baseScore;
    }
  }

  int scoreRouteToTargetRemaining({
    required List<DartThrowResult> route,
    required int startScore,
    required int targetScore,
    required int dartsLeft,
    CheckoutRequirement checkoutRequirement = CheckoutRequirement.doubleOut,
    CheckoutPlayStyle playStyle = CheckoutPlayStyle.balanced,
    int outerBullPreference = 50,
    int bullPreference = 50,
  }) {
    if (route.isEmpty) {
      return -999999;
    }

    final routeBreakdown = routeScoreBreakdown(
      route: route,
      startScore: startScore,
      totalDarts: dartsLeft,
      checkoutRequirement: checkoutRequirement,
      playStyle: playStyle,
      outerBullPreference: outerBullPreference,
      bullPreference: bullPreference,
    );
    final setupComfortRelief = _setupComfortRelief(
      route: route,
      startScore: startScore,
      totalDarts: dartsLeft,
      checkoutRequirement: checkoutRequirement,
      playStyle: playStyle,
      outerBullPreference: outerBullPreference,
      bullPreference: bullPreference,
    );
    final baseRouteScore =
        scoreRoute(
          route: route,
          startScore: startScore,
          totalDarts: dartsLeft,
          checkoutRequirement: checkoutRequirement,
          playStyle: playStyle,
          outerBullPreference: outerBullPreference,
          bullPreference: bullPreference,
        ) -
        routeBreakdown.dartPathScore +
        setupComfortRelief.total;
    final unusedDartPenalty = (dartsLeft - route.length) * 140;
    final setupGuaranteeBonus = _setupGuaranteedFinishAfterMissBonus(
      route: route,
      startScore: startScore,
      totalDarts: dartsLeft,
      checkoutRequirement: checkoutRequirement,
      playStyle: playStyle,
      outerBullPreference: outerBullPreference,
      bullPreference: bullPreference,
    );
    final targetCheckout = bestFinishRoute(
      score: targetScore,
      dartsLeft: 3,
      checkoutRequirement: checkoutRequirement,
      playStyle: playStyle,
      outerBullPreference: outerBullPreference,
      bullPreference: bullPreference,
    );
    final targetLeaveBonus = targetCheckout == null
        ? _targetPreference(targetScore, checkoutRequirement)
        : 220 +
              (scoreRoute(
                    route: targetCheckout,
                    startScore: targetScore,
                    totalDarts: 3,
                    checkoutRequirement: checkoutRequirement,
                    playStyle: playStyle,
                    outerBullPreference: outerBullPreference,
                    bullPreference: bullPreference,
                  ) ~/
                  4);

    return baseRouteScore +
        targetLeaveBonus +
        setupGuaranteeBonus -
        unusedDartPenalty;
  }

  int scoreSetupLeave({
    required List<DartThrowResult> setupRoute,
    required int startScore,
    required int remainingScore,
    required List<DartThrowResult> finishRoute,
    required int dartsLeft,
    CheckoutRequirement checkoutRequirement = CheckoutRequirement.doubleOut,
    CheckoutPlayStyle playStyle = CheckoutPlayStyle.balanced,
    int leavePreference = 50,
    int outerBullPreference = 50,
    int bullPreference = 50,
  }) {
    return setupLeaveScoreBreakdown(
      setupRoute: setupRoute,
      startScore: startScore,
      remainingScore: remainingScore,
      finishRoute: finishRoute,
      dartsLeft: dartsLeft,
      checkoutRequirement: checkoutRequirement,
      playStyle: playStyle,
      leavePreference: leavePreference,
      outerBullPreference: outerBullPreference,
      bullPreference: bullPreference,
    ).totalScore;
  }

  CheckoutSetupScoreBreakdown setupLeaveScoreBreakdown({
    required List<DartThrowResult> setupRoute,
    required int startScore,
    required int remainingScore,
    required List<DartThrowResult> finishRoute,
    required int dartsLeft,
    CheckoutRequirement checkoutRequirement = CheckoutRequirement.doubleOut,
    CheckoutPlayStyle playStyle = CheckoutPlayStyle.balanced,
    int leavePreference = 50,
    int outerBullPreference = 50,
    int bullPreference = 50,
  }) {
    final cacheKey = <Object>[
      setupRoute.map((entry) => entry.label).join('-'),
      startScore,
      remainingScore,
      finishRoute.map((entry) => entry.label).join('-'),
      dartsLeft,
      checkoutRequirement,
      playStyle,
      leavePreference,
      outerBullPreference,
      bullPreference,
    ].join('|');
    final cached = _setupScoreBreakdownCache[cacheKey];
    if (cached != null) {
      return cached;
    }
    final routeBreakdown = routeScoreBreakdown(
      route: setupRoute,
      startScore: startScore,
      totalDarts: dartsLeft,
      checkoutRequirement: checkoutRequirement,
      playStyle: playStyle,
      outerBullPreference: outerBullPreference,
      bullPreference: bullPreference,
    );
    final setupComfortRelief = _setupComfortRelief(
      route: setupRoute,
      startScore: startScore,
      totalDarts: dartsLeft,
      checkoutRequirement: checkoutRequirement,
      playStyle: playStyle,
      outerBullPreference: outerBullPreference,
      bullPreference: bullPreference,
    );
    final adjustedSetupComfort =
        routeBreakdown.comfort + setupComfortRelief.total;
    final setupGuaranteeBonus = _setupGuaranteedFinishAfterMissBonus(
      route: setupRoute,
      startScore: startScore,
      totalDarts: dartsLeft,
      checkoutRequirement: checkoutRequirement,
      playStyle: playStyle,
      outerBullPreference: outerBullPreference,
      bullPreference: bullPreference,
    );
    final earlySetupBullPenalty = _earlySetupBullPenalty(setupRoute);
    final earlySetupDoublePenalty = _earlySetupDoublePenalty(setupRoute);
    final leaveScore = scoreRouteToTargetRemaining(
      route: setupRoute,
      startScore: startScore,
      targetScore: remainingScore,
      dartsLeft: dartsLeft,
      checkoutRequirement: checkoutRequirement,
      playStyle: playStyle,
      outerBullPreference: outerBullPreference,
      bullPreference: bullPreference,
    );
    final missPenalty = setupMissPenalty(
      route: setupRoute,
      startScore: startScore,
      totalDarts: dartsLeft,
      checkoutRequirement: checkoutRequirement,
      playStyle: playStyle,
      outerBullPreference: outerBullPreference,
      bullPreference: bullPreference,
    );
    final simpleWeight = (145 - (leavePreference ~/ 2)).clamp(80, 145);
    final setupPathScore = (leaveScore * simpleWeight) ~/ 100;
    final baseLeaveQuality = leaveQualityBonus(
      remainingScore: remainingScore,
      finishRoute: finishRoute,
      checkoutRequirement: checkoutRequirement,
      playStyle: playStyle,
      outerBullPreference: outerBullPreference,
      bullPreference: bullPreference,
    );
    final leaveQuality = baseLeaveQuality + setupGuaranteeBonus;
    final routeGuidance =
        (routeBreakdown.segmentFlow * 2) - routeBreakdown.narrowFieldPenalty;
    final totalScore =
        routeGuidance +
        leaveQuality -
        missPenalty -
        earlySetupBullPenalty -
        earlySetupDoublePenalty;

    final breakdown = CheckoutSetupScoreBreakdown(
      setupPathScore: setupPathScore,
      routeGuidance: routeGuidance,
      leaveQuality: leaveQuality,
      missPenalty: missPenalty,
      totalScore: totalScore,
      setupPathDetails: <String>[
        'Stellweg-Basis ohne Dart-Weg: $leaveScore',
        'Der Dart-Weg zaehlt im Stell Rechner nicht mit, weil hier derselbe Besuch bewertet wird.',
        if (setupComfortRelief.total > 0)
          'Fruehe Doppel/Triple werden im Stell Rechner neutralisiert: +${setupComfortRelief.total}',
        'Mit Stell-Gewicht $simpleWeight% ergibt das +$setupPathScore',
        'Route-Basis: Komfort ${adjustedSetupComfort >= 0 ? '+' : ''}$adjustedSetupComfort',
        'Route-Basis: Robustheit ${routeBreakdown.robustness >= 0 ? '+' : ''}${routeBreakdown.robustness}',
        'Route-Basis: Doppel ${routeBreakdown.doubleQuality >= 0 ? '+' : ''}${routeBreakdown.doubleQuality}',
        'Route-Basis: Bull-Malus ${routeBreakdown.bullPenalty > 0 ? '-' : '+'}${routeBreakdown.bullPenalty}',
        'Route-Basis: Segmentfluss ${routeBreakdown.segmentFlow >= 0 ? '+' : ''}${routeBreakdown.segmentFlow}',
        ...setupComfortRelief.details,
        ...routeBreakdown.robustnessDetails,
        ...routeBreakdown.doubleQualityDetails,
        ...routeBreakdown.bullPenaltyDetails,
        ...routeBreakdown.segmentFlowDetails,
      ],
      routeGuidanceDetails: <String>[
        'Schmale Felder im Stellweg: -${routeBreakdown.narrowFieldPenalty}',
        'Segmentfluss im Stellweg doppelt gewichtet: ${routeBreakdown.segmentFlow >= 0 ? '+' : ''}${routeBreakdown.segmentFlow * 2}',
        'Gesamt fuer Wegfuehrung: ${routeGuidance >= 0 ? '+' : ''}$routeGuidance',
        ...routeBreakdown.narrowFieldDetails,
        ...routeBreakdown.segmentFlowDetails,
      ],
      leaveQualityDetails:
          _leaveQualityDetails(
            remainingScore: remainingScore,
            bonus: baseLeaveQuality,
            finishRoute: finishRoute,
            checkoutRequirement: checkoutRequirement,
            playStyle: playStyle,
            outerBullPreference: outerBullPreference,
            bullPreference: bullPreference,
          ) +
          (setupGuaranteeBonus > 0
              ? _setupGuaranteedFinishAfterMissDetails(
                  route: setupRoute,
                  startScore: startScore,
                  totalDarts: dartsLeft,
                  checkoutRequirement: checkoutRequirement,
                  playStyle: playStyle,
                  outerBullPreference: outerBullPreference,
                  bullPreference: bullPreference,
                  bonus: setupGuaranteeBonus,
                )
              : const <String>[]),
      missPenaltyDetails: <String>[
        'Miss-Risiko fuer den Stellweg: -$missPenalty',
        if (earlySetupBullPenalty > 0)
          'Fruehe BULL im Stellweg: -$earlySetupBullPenalty',
        if (earlySetupDoublePenalty > 0)
          'Fruehe Doppel im Stellweg: -$earlySetupDoublePenalty',
      ],
    );
    _setupScoreBreakdownCache[cacheKey] = breakdown;
    return breakdown;
  }

  int targetRemainingBonus({
    required int remainingScore,
    required CheckoutRequirement checkoutRequirement,
    required CheckoutPlayStyle playStyle,
    required int outerBullPreference,
    required int bullPreference,
  }) {
    if (remainingScore <= 1) {
      return 0;
    }
    if (remainingScore == 50) {
      return 140 + doublePreference(rules.createBull());
    }
    if (remainingScore > 1 && remainingScore <= 40 && remainingScore.isEven) {
      return 340 + doublePreference(rules.createDouble(remainingScore ~/ 2));
    }
    final finishRoute = bestFinishRoute(
      score: remainingScore,
      dartsLeft: 3,
      checkoutRequirement: checkoutRequirement,
      playStyle: playStyle,
      outerBullPreference: outerBullPreference,
      bullPreference: bullPreference,
    );
    if (finishRoute == null || finishRoute.isEmpty) {
      return 0;
    }
    return 60 +
        (scoreRoute(
              route: finishRoute,
              startScore: remainingScore,
              totalDarts: 3,
              checkoutRequirement: checkoutRequirement,
              playStyle: playStyle,
              outerBullPreference: outerBullPreference,
              bullPreference: bullPreference,
            ) ~/
            8);
  }

  int leaveQualityBonus({
    required int remainingScore,
    required List<DartThrowResult> finishRoute,
    required CheckoutRequirement checkoutRequirement,
    required CheckoutPlayStyle playStyle,
    required int outerBullPreference,
    required int bullPreference,
  }) {
    if (remainingScore <= 1) {
      return 0;
    }
    if (finishRoute.isEmpty) {
      return 0;
    }
    final finishScore = scoreRoute(
      route: finishRoute,
      startScore: remainingScore,
      totalDarts: 3,
      checkoutRequirement: checkoutRequirement,
      playStyle: playStyle,
      outerBullPreference: outerBullPreference,
      bullPreference: bullPreference,
    );
    if (remainingScore == 50) {
      return 180 +
          doublePreference(rules.createBull()) +
          _lowLeaveDepthBonus(remainingScore) +
          (finishScore ~/ 10);
    }
    if (remainingScore > 1 && remainingScore <= 40 && remainingScore.isEven) {
      return 220 +
          doublePreference(rules.createDouble(remainingScore ~/ 2)) +
          _lowLeaveDepthBonus(remainingScore) +
          (finishScore ~/ 10);
    }
    return 140 + (finishScore ~/ 4) + _lowFinishDepthBonus(remainingScore);
  }

  List<String> _leaveQualityDetails({
    required int remainingScore,
    required int bonus,
    required List<DartThrowResult> finishRoute,
    required CheckoutRequirement checkoutRequirement,
    required CheckoutPlayStyle playStyle,
    required int outerBullPreference,
    required int bullPreference,
  }) {
    if (remainingScore <= 1) {
      return <String>['Kein gueltiger Restwert fuer einen Stell-Bonus.'];
    }
    if (finishRoute.isEmpty) {
      return <String>[
        'Kein direktes Doppel-Leave und kein gueltiges Folgefinish: +0',
      ];
    }
    final finishScore = scoreRoute(
      route: finishRoute,
      startScore: remainingScore,
      totalDarts: 3,
      checkoutRequirement: checkoutRequirement,
      playStyle: playStyle,
      outerBullPreference: outerBullPreference,
      bullPreference: bullPreference,
    );
    if (remainingScore == 50) {
      return <String>[
        'Direkter BULL-Rest $remainingScore.',
        'Leave-Qualitaet wie im Checkout Rechner: BULL = +${doublePreference(rules.createBull())}',
        'Tiefer guter Rest: +${_lowLeaveDepthBonus(remainingScore)}',
        'Garantiertes Finish ueber ${finishRoute.map((entry) => entry.label).join(' | ')}: +${finishScore ~/ 10}',
        'Basis fuer direktes Finish-Leave: +180',
        'Gesamt: +$bonus',
      ];
    }
    if (remainingScore > 1 && remainingScore <= 40 && remainingScore.isEven) {
      final doubleThrow = rules.createDouble(remainingScore ~/ 2);
      return <String>[
        'Direktes Doppel-Leave $remainingScore Rest.',
        'Leave-Qualitaet wie im Checkout Rechner: ${doubleThrow.label} = +${doublePreference(doubleThrow)}',
        'Tiefer guter Rest: +${_lowLeaveDepthBonus(remainingScore)}',
        'Garantiertes Finish ueber ${finishRoute.map((entry) => entry.label).join(' | ')}: +${finishScore ~/ 10}',
        'Basis fuer direktes Finish-Leave: +220',
        'Gesamt: +$bonus',
      ];
    }
    return <String>[
      'Garantiertes Finish auf $remainingScore Rest.',
      'Bestes Finish danach ${finishRoute.map((entry) => entry.label).join(' | ')}',
      'Finish-Qualitaet des Leaves: +${finishScore ~/ 4}',
      'Tiefes gutes Folgefinish: +${_lowFinishDepthBonus(remainingScore)}',
      'Basis fuer garantiertes Finish-Leave: +140',
      'Gesamt: +$bonus',
    ];
  }

  int _lowLeaveDepthBonus(int remainingScore) {
    if (remainingScore == 50) {
      return 16;
    }
    if (remainingScore > 1 && remainingScore <= 40 && remainingScore.isEven) {
      return ((42 - remainingScore).clamp(0, 40)) * 4;
    }
    return 0;
  }

  int _lowFinishDepthBonus(int remainingScore) {
    if (remainingScore <= 1) {
      return 0;
    }
    return ((81 - remainingScore).clamp(0, 50)) ~/ 2;
  }

  int setupMissPenalty({
    required List<DartThrowResult> route,
    required int startScore,
    required int totalDarts,
    CheckoutRequirement checkoutRequirement = CheckoutRequirement.doubleOut,
    CheckoutPlayStyle playStyle = CheckoutPlayStyle.balanced,
    int outerBullPreference = 50,
    int bullPreference = 50,
  }) {
    var remaining = startScore;
    var penalty = 0;

    for (var index = 0; index < route.length; index += 1) {
      final dartThrow = route[index];
      final dartsAfterThis = totalDarts - index - 1;

      if (dartThrow.isTriple && dartsAfterThis > 0) {
        penalty += _penaltyForSetupMiss(
          remainingScore: remaining - dartThrow.baseValue,
          dartsLeft: dartsAfterThis,
          checkoutRequirement: checkoutRequirement,
          playStyle: playStyle,
          outerBullPreference: outerBullPreference,
          bullPreference: bullPreference,
          isPrimaryMiss: index == 0,
        );
      } else if (dartThrow.isDouble && !dartThrow.isBull) {
        penalty += _penaltyForSetupMiss(
          remainingScore: remaining - dartThrow.baseValue,
          dartsLeft: dartsAfterThis,
          checkoutRequirement: checkoutRequirement,
          playStyle: playStyle,
          outerBullPreference: outerBullPreference,
          bullPreference: bullPreference,
          isPrimaryMiss: index == 0,
        );
        if (dartsAfterThis > 0) {
          penalty += _penaltyForDoubleZeroMiss(
            remainingScore: remaining,
            dartsLeft: dartsAfterThis,
            checkoutRequirement: checkoutRequirement,
            playStyle: playStyle,
            outerBullPreference: outerBullPreference,
            bullPreference: bullPreference,
            isPrimaryMiss: index == 0,
          );
        }
      } else if (dartThrow.isBull && dartsAfterThis > 0) {
        penalty += _penaltyForSetupMiss(
          remainingScore: remaining - 25,
          dartsLeft: dartsAfterThis,
          checkoutRequirement: checkoutRequirement,
          playStyle: playStyle,
          outerBullPreference: outerBullPreference,
          bullPreference: bullPreference,
          isPrimaryMiss: index == 0,
        );
      }

      remaining -= dartThrow.scoredPoints;
    }

    return penalty;
  }

  int _penaltyForSetupMiss({
    required int remainingScore,
    required int dartsLeft,
    required CheckoutRequirement checkoutRequirement,
    required CheckoutPlayStyle playStyle,
    required int outerBullPreference,
    required int bullPreference,
    bool isPrimaryMiss = false,
    bool isNeighborMiss = false,
  }) {
    if (remainingScore <= 1 || dartsLeft <= 0) {
      return isPrimaryMiss ? 90 : 70;
    }

    final continuation = bestContinuationPlan(
      score: remainingScore,
      dartsLeft: dartsLeft,
      checkoutRequirement: checkoutRequirement,
      playStyle: playStyle,
      outerBullPreference: outerBullPreference,
      bullPreference: bullPreference,
    );

    if (continuation == null || continuation.throws.isEmpty) {
      return isPrimaryMiss
          ? (isNeighborMiss ? 62 : 74)
          : (isNeighborMiss ? 54 : 62);
    }

    if (continuation.immediateFinish) {
      return isNeighborMiss ? -10 : -18;
    }

    return isNeighborMiss ? 18 : 26;
  }

  int _penaltyForDoubleZeroMiss({
    required int remainingScore,
    required int dartsLeft,
    required CheckoutRequirement checkoutRequirement,
    required CheckoutPlayStyle playStyle,
    required int outerBullPreference,
    required int bullPreference,
    bool isPrimaryMiss = false,
  }) {
    if (remainingScore <= 1 || dartsLeft <= 0) {
      return 0;
    }

    final exactFinish = bestFinishRoute(
      score: remainingScore,
      dartsLeft: dartsLeft,
      checkoutRequirement: checkoutRequirement,
      playStyle: playStyle,
      outerBullPreference: outerBullPreference,
      bullPreference: bullPreference,
    );
    if (exactFinish != null && exactFinish.isNotEmpty) {
      return isPrimaryMiss ? 24 : 12;
    }

    final continuation = bestContinuationPlan(
      score: remainingScore,
      dartsLeft: dartsLeft,
      checkoutRequirement: checkoutRequirement,
      playStyle: playStyle,
      outerBullPreference: outerBullPreference,
      bullPreference: bullPreference,
    );
    if (continuation == null || continuation.throws.isEmpty) {
      return isPrimaryMiss ? 110 : 70;
    }

    return continuation.immediateFinish
        ? (isPrimaryMiss ? 24 : 12)
        : (isPrimaryMiss ? 70 : 42);
  }

  int robustnessScore({
    required List<DartThrowResult> route,
    required int startScore,
    required int totalDarts,
    CheckoutRequirement checkoutRequirement = CheckoutRequirement.doubleOut,
    CheckoutPlayStyle playStyle = CheckoutPlayStyle.balanced,
    int outerBullPreference = 50,
    int bullPreference = 50,
  }) {
    return _robustnessDetails(
      route: route,
      startScore: startScore,
      totalDarts: totalDarts,
      checkoutRequirement: checkoutRequirement,
      playStyle: playStyle,
      outerBullPreference: outerBullPreference,
      bullPreference: bullPreference,
    ).total;
  }

  _ScoreDetails _robustnessDetails({
    required List<DartThrowResult> route,
    required int startScore,
    required int totalDarts,
    CheckoutRequirement checkoutRequirement = CheckoutRequirement.doubleOut,
    CheckoutPlayStyle playStyle = CheckoutPlayStyle.balanced,
    int outerBullPreference = 50,
    int bullPreference = 50,
  }) {
    var remaining = startScore;
    var score = 0;
    final details = <String>[];
    final isThreeDartFinish = route.length == 3;
    var premiumBetterThanBullTripleFallbackUsed = false;

    for (var index = 0; index < route.length; index += 1) {
      final dartThrow = route[index];
      final dartsAfterThis = totalDarts - index - 1;

      if (dartThrow.isTriple && dartsAfterThis > 0) {
        final singleFallbackRemaining = remaining - dartThrow.baseValue;
        if (singleFallbackRemaining > 1) {
          final urgencyBonus = index == 0 ? 42 : 0;
          final exactFallback = bestFinishRoute(
            score: singleFallbackRemaining,
            dartsLeft: dartsAfterThis,
            checkoutRequirement: checkoutRequirement,
            playStyle: playStyle,
            outerBullPreference: outerBullPreference,
            bullPreference: bullPreference,
          );

          if (exactFallback != null && exactFallback.isNotEmpty) {
            final fallbackScore = simpleRouteScore(
              exactFallback,
              playStyle: playStyle,
              outerBullPreference: outerBullPreference,
              bullPreference: bullPreference,
            );
            final fallbackFinishBonus =
                doublePreference(exactFallback.last).clamp(0, 140) ~/ 6;
            final oneDartFinishBonus = exactFallback.length == 1 ? 18 : 0;
            final noTripleFallbackBonus =
                exactFallback.any((entry) => entry.isTriple) ? 0 : 20;
            final bullRescueBonus =
                exactFallback.length == 1 && exactFallback.last.isBull ? 60 : 0;
            final narrowFallbackPenalty =
                exactFallback.where(isNarrowField).length * 22;
            final sameSegmentFallbackBonus =
                exactFallback.isNotEmpty &&
                    exactFallback.first.baseValue == dartThrow.baseValue
                ? 72
                : 0;
            final doubleLeaveBonus = directDoubleLeaveBonus(
              route: exactFallback,
              startScore: singleFallbackRemaining,
            );
            final firstDartImmediateFinishBonus =
                index == 0 && exactFallback.length <= dartsAfterThis ? 90 : 0;
            final isPremiumBetterThanBullTripleFallback =
                exactFallback.where((entry) => entry.isTriple).length == 1 &&
                !exactFallback.last.isBull &&
                exactFallback.last.matchesCheckoutRequirement(
                  checkoutRequirement,
                );
            final limitAdditionalTripleFallbackBonus =
                premiumBetterThanBullTripleFallbackUsed;
            final effectiveFallbackFinishBonus =
                limitAdditionalTripleFallbackBonus ? 0 : fallbackFinishBonus;
            final effectiveOneDartFinishBonus =
                limitAdditionalTripleFallbackBonus ? 0 : oneDartFinishBonus;
            final effectiveFirstDartImmediateFinishBonus =
                limitAdditionalTripleFallbackBonus
                ? 0
                : firstDartImmediateFinishBonus;
            final rawPartScore = limitAdditionalTripleFallbackBonus
                ? 0
                : index == 0
                ? 180
                : 28 +
                      urgencyBonus +
                      effectiveFirstDartImmediateFinishBonus +
                      (fallbackScore ~/ 11) +
                      effectiveFallbackFinishBonus +
                      effectiveOneDartFinishBonus +
                      noTripleFallbackBonus +
                      bullRescueBonus -
                      narrowFallbackPenalty +
                      sameSegmentFallbackBonus +
                      doubleLeaveBonus;
            final threeDartReduction = isThreeDartFinish
                ? (index == 0 ? 45 : 60)
                : 0;
            final partScore = rawPartScore - threeDartReduction;
            score += partScore;
            details.add(
              '${index + 1}. Dart ${dartThrow.label} -> Single-Fallback $singleFallbackRemaining: '
              '${partScore >= 0 ? '+' : ''}$partScore',
            );
            details.add(
              limitAdditionalTripleFallbackBonus
                  ? '  Weiterer Triple-Fallbackbonus gesperrt, weil bereits ein besser-als-Bull-Fallback mit genau einem Triple offen ist: +0'
                  : index == 0
                  ? '  Einheitlicher 1. Dart-Finish-Fallback: +150'
                  : '  Basis +28, Dringlichkeit ${urgencyBonus >= 0 ? '+' : ''}$urgencyBonus, '
                        'Finish-offen ${effectiveFirstDartImmediateFinishBonus >= 0 ? '+' : ''}$effectiveFirstDartImmediateFinishBonus, '
                        'Fallback-Qualitaet ${((fallbackScore ~/ 11) >= 0 ? '+' : '')}${fallbackScore ~/ 11}, '
                        'Doppel ${effectiveFallbackFinishBonus >= 0 ? '+' : ''}$effectiveFallbackFinishBonus, '
                        '1-Dart-Finish ${effectiveOneDartFinishBonus >= 0 ? '+' : ''}$effectiveOneDartFinishBonus, '
                        'ohne Triple ${noTripleFallbackBonus >= 0 ? '+' : ''}$noTripleFallbackBonus, '
                        'Bull-Rettung ${bullRescueBonus >= 0 ? '+' : ''}$bullRescueBonus, '
                        'Schmalfeld -$narrowFallbackPenalty, '
                        'gleiches Segment ${sameSegmentFallbackBonus >= 0 ? '+' : ''}$sameSegmentFallbackBonus, '
                        'Doppel-Leave ${doubleLeaveBonus >= 0 ? '+' : ''}$doubleLeaveBonus',
            );
            if (isPremiumBetterThanBullTripleFallback) {
              premiumBetterThanBullTripleFallbackUsed = true;
            }
            if (threeDartReduction > 0) {
              details.add(
                '  3-Dart-Finish-Reduktion ${threeDartReduction >= 0 ? '-' : '+'}$threeDartReduction, '
                'damit Fallback und Hauptweg nicht doppelt belohnt werden.',
              );
            }
          } else {
            final fallbackPlan = bestContinuationPlan(
              score: singleFallbackRemaining,
              dartsLeft: dartsAfterThis,
              checkoutRequirement: checkoutRequirement,
              playStyle: playStyle,
              outerBullPreference: outerBullPreference,
              bullPreference: bullPreference,
            );
            if (fallbackPlan != null && fallbackPlan.throws.isNotEmpty) {
              final fallbackScore = simpleRouteScore(
                fallbackPlan.throws.take(dartsAfterThis).toList(),
                playStyle: playStyle,
                outerBullPreference: outerBullPreference,
                bullPreference: bullPreference,
              );
              final partScore =
                  !fallbackPlan.immediateFinish && dartsAfterThis == 1
                  ? 0
                  : fallbackPlan.immediateFinish
                  ? 10 +
                        urgencyBonus +
                        (index == 0 ? 18 : 0) +
                        (fallbackScore ~/ 36)
                  : -24 - (index == 0 ? 40 : 12) + (fallbackScore ~/ 120);
              score += partScore;
              details.add(
                '${index + 1}. Dart ${dartThrow.label} -> Plan-Fallback $singleFallbackRemaining: '
                '${partScore >= 0 ? '+' : ''}$partScore',
              );
              details.add(
                '  ${fallbackPlan.immediateFinish ? 'Sofort-Finish' : 'Setup-Plan'}, '
                'Dringlichkeit ${urgencyBonus >= 0 ? '+' : ''}$urgencyBonus, '
                '1. Dart-Extra ${index == 0 && fallbackPlan.immediateFinish ? '+18' : '+0'}, '
                'Plan-Qualitaet ${((fallbackScore ~/ (fallbackPlan.immediateFinish ? 36 : 120)) >= 0 ? '+' : '')}'
                '${fallbackScore ~/ (fallbackPlan.immediateFinish ? 36 : 120)}',
              );
            } else {
              final partScore = dartsAfterThis == 1
                  ? 0
                  : -(index == 0 ? 100 : 80);
              score += partScore;
              details.add(
                '${index + 1}. Dart ${dartThrow.label} -> kein brauchbarer Single-Fallback: $partScore',
              );
            }
          }
        }
      }

      if (dartThrow.isBull && dartsAfterThis > 0) {
        final outerBullFallbackRemaining = remaining - 25;
        if (outerBullFallbackRemaining > 1) {
          final exactFallback = bestFinishRoute(
            score: outerBullFallbackRemaining,
            dartsLeft: dartsAfterThis,
            checkoutRequirement: checkoutRequirement,
            playStyle: playStyle,
            outerBullPreference: outerBullPreference,
            bullPreference: bullPreference,
          );

          if (exactFallback != null && exactFallback.isNotEmpty) {
            final fallbackScore = simpleRouteScore(
              exactFallback,
              playStyle: playStyle,
              outerBullPreference: outerBullPreference,
              bullPreference: bullPreference,
            );
            final finishBonus =
                doublePreference(exactFallback.last).clamp(0, 140) ~/ 8;
            final oneDartFinishBonus = exactFallback.length == 1 ? 20 : 0;
            final repeatedBullBonus =
                exactFallback.isNotEmpty && exactFallback.first.isBull ? 54 : 0;
            final doubleLeaveBonus = directDoubleLeaveBonus(
              route: exactFallback,
              startScore: outerBullFallbackRemaining,
            );
            final firstDartImmediateFinishBonus =
                index == 0 && exactFallback.length <= dartsAfterThis ? 60 : 0;
            final bullFallbackBonus = index == 0 ? 48 : 24;
            final rawPartScore = index == 0
                ? 180
                : 22 +
                      bullFallbackBonus +
                      firstDartImmediateFinishBonus +
                      (fallbackScore ~/ 12) +
                      finishBonus +
                      oneDartFinishBonus +
                      repeatedBullBonus +
                      doubleLeaveBonus;
            final threeDartReduction = isThreeDartFinish
                ? (index == 0 ? 45 : 60)
                : 0;
            final partScore = rawPartScore - threeDartReduction;
            score += partScore;
            details.add(
              '${index + 1}. Dart BULL -> 25-Fallback $outerBullFallbackRemaining: '
              '${partScore >= 0 ? '+' : ''}$partScore',
            );
            details.add(
              index == 0
                  ? '  Einheitlicher 1. Dart-Finish-Fallback: +150'
                  : '  Basis +22, Bull-Dringlichkeit ${bullFallbackBonus >= 0 ? '+' : ''}$bullFallbackBonus, '
                        'Finish-offen ${firstDartImmediateFinishBonus >= 0 ? '+' : ''}$firstDartImmediateFinishBonus, '
                        'Fallback-Qualitaet ${((fallbackScore ~/ 12) >= 0 ? '+' : '')}${fallbackScore ~/ 12}, '
                        'Doppel ${finishBonus >= 0 ? '+' : ''}$finishBonus, '
                        '1-Dart-Finish ${oneDartFinishBonus >= 0 ? '+' : ''}$oneDartFinishBonus, '
                        'Bull-Kette ${repeatedBullBonus >= 0 ? '+' : ''}$repeatedBullBonus, '
                        'Doppel-Leave ${doubleLeaveBonus >= 0 ? '+' : ''}$doubleLeaveBonus',
            );
            if (threeDartReduction > 0) {
              details.add(
                '  3-Dart-Finish-Reduktion ${threeDartReduction >= 0 ? '-' : '+'}$threeDartReduction, '
                'damit Fallback und Hauptweg nicht doppelt belohnt werden.',
              );
            }
          } else {
            final fallbackPlan = bestContinuationPlan(
              score: outerBullFallbackRemaining,
              dartsLeft: dartsAfterThis,
              checkoutRequirement: checkoutRequirement,
              playStyle: playStyle,
              outerBullPreference: outerBullPreference,
              bullPreference: bullPreference,
            );
            if (fallbackPlan != null && fallbackPlan.throws.isNotEmpty) {
              final fallbackScore = simpleRouteScore(
                fallbackPlan.throws.take(dartsAfterThis).toList(),
                playStyle: playStyle,
                outerBullPreference: outerBullPreference,
                bullPreference: bullPreference,
              );
              final partScore =
                  !fallbackPlan.immediateFinish && dartsAfterThis == 1
                  ? 0
                  : fallbackPlan.immediateFinish
                  ? 18 + (index == 0 ? 34 : 24) + (fallbackScore ~/ 40)
                  : -24 - (index == 0 ? 40 : 12) + (fallbackScore ~/ 120);
              score += partScore;
              details.add(
                '${index + 1}. Dart BULL -> 25-Fallback $outerBullFallbackRemaining: '
                '${partScore >= 0 ? '+' : ''}$partScore',
              );
              details.add(
                '  ${fallbackPlan.immediateFinish ? 'Sofort-Finish' : 'Setup-Plan'}, '
                'Bull-Extra ${((fallbackPlan.immediateFinish ? (index == 0 ? 34 : 24) : 0) >= 0 ? '+' : '')}'
                '${fallbackPlan.immediateFinish ? (index == 0 ? 34 : 24) : 0}, '
                'Plan-Qualitaet ${((fallbackScore ~/ (fallbackPlan.immediateFinish ? 40 : 120)) >= 0 ? '+' : '')}'
                '${fallbackScore ~/ (fallbackPlan.immediateFinish ? 40 : 120)}',
              );
            } else {
              final partScore = dartsAfterThis == 1
                  ? 0
                  : -(index == 0 ? 42 : 14);
              score += partScore;
              details.add(
                '${index + 1}. Dart BULL -> kein brauchbarer 25-Fallback $outerBullFallbackRemaining: $partScore',
              );
            }
          }
        }
      }

      if (dartThrow.isDouble && !dartThrow.isBull && dartsAfterThis > 0) {
        final exactFallback = bestFinishRoute(
          score: remaining,
          dartsLeft: dartsAfterThis,
          checkoutRequirement: checkoutRequirement,
          playStyle: playStyle,
          outerBullPreference: outerBullPreference,
          bullPreference: bullPreference,
        );
        if (exactFallback != null && exactFallback.isNotEmpty) {
          final partScore = index == 0 ? -24 : -12;
          score += partScore;
          details.add(
            '${index + 1}. Dart ${dartThrow.label} -> Miss-Fallback ohne Punkte $remaining: $partScore',
          );
          details.add(
            '  Fruehes Doppel kann bei Fehlwurf 0 Punkte lassen, obwohl noch ein Finish offen bleibt.',
          );
        } else {
          final continuation = bestContinuationPlan(
            score: remaining,
            dartsLeft: dartsAfterThis,
            checkoutRequirement: checkoutRequirement,
            playStyle: playStyle,
            outerBullPreference: outerBullPreference,
            bullPreference: bullPreference,
          );
          final partScore = continuation == null || continuation.throws.isEmpty
              ? (index == 0 ? -110 : -70)
              : continuation.immediateFinish
              ? (index == 0 ? -24 : -12)
              : (index == 0 ? -70 : -42);
          score += partScore;
          details.add(
            '${index + 1}. Dart ${dartThrow.label} -> Miss-Fallback ohne Punkte $remaining: $partScore',
          );
          details.add(
            '  Fruehes Doppel kann bei Fehlwurf 0 Punkte lassen und den Weg deutlich verschlechtern.',
          );
        }
      }

      if (dartThrow.label == '25' && dartsAfterThis > 0) {
        final bullFallbackRemaining = remaining - 50;
        var partScore = index == 0 ? 16 : 8;

        if (bullFallbackRemaining > 1) {
          final exactFallback = bestFinishRoute(
            score: bullFallbackRemaining,
            dartsLeft: dartsAfterThis,
            checkoutRequirement: checkoutRequirement,
            playStyle: playStyle,
            outerBullPreference: outerBullPreference,
            bullPreference: bullPreference,
          );

          if (exactFallback != null && exactFallback.isNotEmpty) {
            final fallbackScore = simpleRouteScore(
              exactFallback,
              playStyle: playStyle,
              outerBullPreference: outerBullPreference,
              bullPreference: bullPreference,
            );
            partScore += 18 + (fallbackScore ~/ 48);
          } else {
            final fallbackPlan = bestContinuationPlan(
              score: bullFallbackRemaining,
              dartsLeft: dartsAfterThis,
              checkoutRequirement: checkoutRequirement,
              playStyle: playStyle,
              outerBullPreference: outerBullPreference,
              bullPreference: bullPreference,
            );
            if (fallbackPlan != null && fallbackPlan.throws.isNotEmpty) {
              partScore += fallbackPlan.immediateFinish ? 12 : 4;
            }
          }
        }

        score += partScore;
        details.add(
          '${index + 1}. Dart 25 -> BULL-Fallback ${bullFallbackRemaining > 1 ? bullFallbackRemaining : 0}: '
          '${partScore >= 0 ? '+' : ''}$partScore',
        );
        details.add(
          '  Basis ${((index == 0 ? 16 : 8) >= 0 ? '+' : '')}${index == 0 ? 16 : 8}, '
          'Fallback-Zusatz ${((partScore - (index == 0 ? 16 : 8)) >= 0 ? '+' : '')}${partScore - (index == 0 ? 16 : 8)}',
        );
      }

      remaining -= dartThrow.scoredPoints;
    }

    if (details.isEmpty) {
      details.add('Keine relevanten Fehlwurf-Boni oder -Mali in dieser Route.');
    }

    return _ScoreDetails(total: score, details: details);
  }

  int comfortScore(List<DartThrowResult> route) {
    if (route.isEmpty) {
      return 0;
    }

    var score = 0;
    for (var index = 0; index < route.length; index += 1) {
      final dartThrow = route[index];
      final isLast = index == route.length - 1;

      if (!isLast) {
        if (dartThrow.isTriple) {
          score -= 75;
        } else if (dartThrow.isBull) {
          score -= 85;
        } else if (dartThrow.isDouble && !dartThrow.isBull) {
          score -= 100;
        } else if (dartThrow.label == '25') {
          score -= 50;
        } else if (!dartThrow.isBull) {
          score += 75;
        }
      }
    }

    return score;
  }

  int _smallTripleOver100Penalty({
    required List<DartThrowResult> route,
    required int startScore,
  }) {
    var penalty = 0;
    var remaining = startScore;
    for (final dartThrow in route) {
      if (remaining > 100 &&
          dartThrow.isTriple &&
          dartThrow.baseValue > 0 &&
          dartThrow.baseValue < 15) {
        penalty -= 25;
      }
      remaining -= dartThrow.scoredPoints;
    }
    return penalty;
  }

  _SetupComfortRelief _setupComfortRelief({
    required List<DartThrowResult> route,
    required int startScore,
    required int totalDarts,
    required CheckoutRequirement checkoutRequirement,
    required CheckoutPlayStyle playStyle,
    required int outerBullPreference,
    required int bullPreference,
  }) {
    if (route.isEmpty) {
      return const _SetupComfortRelief(total: 0, details: <String>[]);
    }

    var relief = 0;
    final details = <String>[];
    var remaining = startScore;
    for (var index = 0; index < route.length; index += 1) {
      final dartThrow = route[index];
      final dartsAfterThis = totalDarts - index - 1;
      if (dartThrow.isTriple) {
        if (dartsAfterThis > 0) {
          final singleFallbackRemaining = remaining - dartThrow.baseValue;
          final finishFallback = bestFinishRoute(
            score: singleFallbackRemaining,
            dartsLeft: dartsAfterThis,
            checkoutRequirement: checkoutRequirement,
            playStyle: playStyle,
            outerBullPreference: outerBullPreference,
            bullPreference: bullPreference,
          );
          if (finishFallback != null && finishFallback.isNotEmpty) {
            relief += 75;
            details.add(
              '${dartThrow.label}: +75 Komfort-Entlastung im Stell Rechner (Finish-Fallback $singleFallbackRemaining vorhanden)',
            );
          }
        }
      } else if (dartThrow.isBull) {
        if (dartsAfterThis > 0) {
          final outerBullFallbackRemaining = remaining - 25;
          final finishFallback = bestFinishRoute(
            score: outerBullFallbackRemaining,
            dartsLeft: dartsAfterThis,
            checkoutRequirement: checkoutRequirement,
            playStyle: playStyle,
            outerBullPreference: outerBullPreference,
            bullPreference: bullPreference,
          );
          if (finishFallback != null && finishFallback.isNotEmpty) {
            relief += 85;
            details.add(
              'BULL: +85 Komfort-Entlastung im Stell Rechner (Finish-Fallback $outerBullFallbackRemaining vorhanden)',
            );
          }
        }
      } else if (dartThrow.isDouble && !dartThrow.isBull) {
        relief += 100;
        details.add(
          '${dartThrow.label}: +100 Komfort-Entlastung im Stell Rechner (fruehes Doppel neutralisiert)',
        );
      }
      remaining -= dartThrow.scoredPoints;
    }

    return _SetupComfortRelief(total: relief, details: details);
  }

  int _setupGuaranteedFinishAfterMissBonus({
    required List<DartThrowResult> route,
    required int startScore,
    required int totalDarts,
    required CheckoutRequirement checkoutRequirement,
    required CheckoutPlayStyle playStyle,
    required int outerBullPreference,
    required int bullPreference,
  }) {
    if (route.isEmpty || totalDarts <= 1) {
      return 0;
    }

    final first = route.first;
    int? fallbackRemaining;
    if (first.isTriple || (first.isDouble && !first.isBull)) {
      fallbackRemaining = startScore - first.baseValue;
    } else if (first.isBull) {
      fallbackRemaining = startScore - 25;
    }

    if (fallbackRemaining == null || fallbackRemaining <= 1) {
      return 0;
    }

    final fallbackFinish = bestFinishRoute(
      score: fallbackRemaining,
      dartsLeft: totalDarts - 1,
      checkoutRequirement: checkoutRequirement,
      playStyle: playStyle,
      outerBullPreference: outerBullPreference,
      bullPreference: bullPreference,
    );
    if (fallbackFinish == null || fallbackFinish.isEmpty) {
      return 0;
    }

    return 220 +
        (scoreRoute(
              route: fallbackFinish,
              startScore: fallbackRemaining,
              totalDarts: totalDarts - 1,
              checkoutRequirement: checkoutRequirement,
              playStyle: playStyle,
              outerBullPreference: outerBullPreference,
              bullPreference: bullPreference,
            ) ~/
            10);
  }

  List<String> _setupGuaranteedFinishAfterMissDetails({
    required List<DartThrowResult> route,
    required int startScore,
    required int totalDarts,
    required CheckoutRequirement checkoutRequirement,
    required CheckoutPlayStyle playStyle,
    required int outerBullPreference,
    required int bullPreference,
    required int bonus,
  }) {
    if (route.isEmpty || totalDarts <= 1) {
      return const <String>[];
    }

    final first = route.first;
    int? fallbackRemaining;
    String? missLabel;
    if (first.isTriple || (first.isDouble && !first.isBull)) {
      fallbackRemaining = startScore - first.baseValue;
      missLabel = first.isTriple
          ? 'Single statt ${first.label}'
          : 'Single statt ${first.label}';
    } else if (first.isBull) {
      fallbackRemaining = startScore - 25;
      missLabel = '25 statt BULL';
    }

    if (fallbackRemaining == null ||
        fallbackRemaining <= 1 ||
        missLabel == null) {
      return const <String>[];
    }

    final fallbackFinish = bestFinishRoute(
      score: fallbackRemaining,
      dartsLeft: totalDarts - 1,
      checkoutRequirement: checkoutRequirement,
      playStyle: playStyle,
      outerBullPreference: outerBullPreference,
      bullPreference: bullPreference,
    );
    if (fallbackFinish == null || fallbackFinish.isEmpty) {
      return const <String>[];
    }

    return <String>[
      'Finish-Garantie nach 1. Dart-Miss: +$bonus',
      '$missLabel laesst mit ${fallbackFinish.map((entry) => entry.label).join(' | ')} trotzdem einen kompletten Checkout offen.',
    ];
  }

  int _earlySetupBullPenalty(List<DartThrowResult> route) {
    return route.take(2).where((entry) => entry.isBull).length * 50;
  }

  int _earlySetupDoublePenalty(List<DartThrowResult> route) {
    return route
            .take(2)
            .where((entry) => entry.isDouble && !entry.isBull)
            .length *
        120;
  }

  int setupComfortScore(List<DartThrowResult> route) {
    if (route.isEmpty) {
      return 0;
    }

    var score = 0;
    for (final dartThrow in route) {
      if (dartThrow.isTriple) {
        score -= 75;
      } else if (dartThrow.isBull) {
        score -= 85;
      } else if (dartThrow.isDouble && !dartThrow.isBull) {
        score -= 100;
      } else if (dartThrow.label == '25') {
        score -= 50;
      } else if (!dartThrow.isBull) {
        score += 75;
      }
    }

    return score;
  }

  int _checkoutFallbackComfortRelief({
    required List<DartThrowResult> route,
    required int startScore,
    required int totalDarts,
    required CheckoutRequirement checkoutRequirement,
    required CheckoutPlayStyle playStyle,
    required int outerBullPreference,
    required int bullPreference,
  }) {
    var remaining = startScore;
    var relief = 0;

    for (var index = 0; index < route.length - 1; index += 1) {
      final dartThrow = route[index];
      final dartsAfterThis = totalDarts - index - 1;
      if (dartsAfterThis <= 0) {
        remaining -= dartThrow.scoredPoints;
        continue;
      }

      if (dartThrow.isTriple) {
        final singleFallbackRemaining = remaining - dartThrow.baseValue;
        final finishFallback = bestFinishRoute(
          score: singleFallbackRemaining,
          dartsLeft: dartsAfterThis,
          checkoutRequirement: checkoutRequirement,
          playStyle: playStyle,
          outerBullPreference: outerBullPreference,
          bullPreference: bullPreference,
        );
        if (finishFallback != null && finishFallback.isNotEmpty) {
          relief += 85;
        }
      } else if (dartThrow.isBull) {
        final outerBullFallbackRemaining = remaining - 25;
        final finishFallback = bestFinishRoute(
          score: outerBullFallbackRemaining,
          dartsLeft: dartsAfterThis,
          checkoutRequirement: checkoutRequirement,
          playStyle: playStyle,
          outerBullPreference: outerBullPreference,
          bullPreference: bullPreference,
        );
        if (finishFallback != null && finishFallback.isNotEmpty) {
          relief += 85;
        }
      }

      remaining -= dartThrow.scoredPoints;
    }

    return relief;
  }

  List<String> _dartPathDetails({
    required int routeLength,
    required int baseScore,
    required int twoDartBonus,
  }) {
    final total = baseScore + twoDartBonus;
    return <String>[
      'Zusammengefasster Weg-Score fuer $routeLength Dart: +$total',
      if (twoDartBonus != 0)
        'Darin enthalten ist ein 2-Dart-Bonus von +$twoDartBonus',
      if (twoDartBonus == 0) 'Kein zusaetzlicher 2-Dart-Bonus.',
    ];
  }

  List<String> _comfortDetails(
    List<DartThrowResult> route, {
    required int startScore,
    required int totalDarts,
    required CheckoutRequirement checkoutRequirement,
    required CheckoutPlayStyle playStyle,
    required int outerBullPreference,
    required int bullPreference,
  }) {
    final details = <String>[];
    var remaining = startScore;
    for (var index = 0; index < route.length - 1; index += 1) {
      final dartThrow = route[index];
      final dartsAfterThis = totalDarts - index - 1;
      if (dartThrow.isTriple) {
        details.add('${dartThrow.label}: -75 als fruehes Triple');
        final singleFallbackRemaining = remaining - dartThrow.baseValue;
        final finishFallback = bestFinishRoute(
          score: singleFallbackRemaining,
          dartsLeft: dartsAfterThis,
          checkoutRequirement: checkoutRequirement,
          playStyle: playStyle,
          outerBullPreference: outerBullPreference,
          bullPreference: bullPreference,
        );
        if (finishFallback != null && finishFallback.isNotEmpty) {
          details.add(
            '${dartThrow.label}: +75 Komfort-Entlastung wegen Finish-Fallback $singleFallbackRemaining',
          );
        }
      } else if (dartThrow.isBull) {
        details.add('BULL: -85 als frueher BULL');
        final outerBullFallbackRemaining = remaining - 25;
        final finishFallback = bestFinishRoute(
          score: outerBullFallbackRemaining,
          dartsLeft: dartsAfterThis,
          checkoutRequirement: checkoutRequirement,
          playStyle: playStyle,
          outerBullPreference: outerBullPreference,
          bullPreference: bullPreference,
        );
        if (finishFallback != null && finishFallback.isNotEmpty) {
          details.add(
            'BULL: +85 Komfort-Entlastung wegen Finish-Fallback $outerBullFallbackRemaining',
          );
        }
      } else if (dartThrow.isDouble && !dartThrow.isBull) {
        details.add('${dartThrow.label}: -100 als fruehes Doppel');
      } else if (dartThrow.label == '25') {
        details.add('25: -50 als fruehes schmales Feld');
      } else if (!dartThrow.isBull) {
        details.add('${dartThrow.label}: +75 als fruehes Single');
      }
      remaining -= dartThrow.scoredPoints;
    }
    remaining = startScore;
    for (final dartThrow in route) {
      if (remaining > 100 &&
          dartThrow.isTriple &&
          dartThrow.baseValue > 0 &&
          dartThrow.baseValue < 15) {
        details.add(
          '${dartThrow.label}: -25 kleines Triple unter T15 bei Rest $remaining',
        );
      }
      remaining -= dartThrow.scoredPoints;
    }
    if (details.isEmpty) {
      details.add('Nur der Schlussdart vorhanden, daher kein Komfort-Anteil.');
    }
    return details;
  }

  List<String> _doubleDetails(DartThrowResult? finalThrow) {
    if (finalThrow == null) {
      return <String>['Kein Schlussdart vorhanden.'];
    }
    if (!finalThrow.isFinishDouble) {
      return <String>['Kein gueltiges Schlussdoppel, daher +0.'];
    }
    if (finalThrow.isBull) {
      return <String>['BULL als Schlussfeld: +25'];
    }

    var halvingCount = 0;
    var value = finalThrow.baseValue;
    while (value > 0 && value.isEven) {
      halvingCount += 1;
      value ~/= 2;
    }

    final score = halvingCount * 12;
    return <String>[
      '${finalThrow.baseValue} ist $halvingCount mal durch 2 teilbar: +${halvingCount * 12}',
      'Gesamt: +$score',
    ];
  }

  List<String> _bullPenaltyDetails({
    required List<DartThrowResult> route,
    required int finalBullPenalty,
    required int outerBullPenalty,
  }) {
    final details = <String>[];
    final outerBullCount = route.where((entry) => entry.label == '25').length;
    if (route.isNotEmpty && route.last.isBull) {
      details.add('BULL als Schlussdart: -$finalBullPenalty');
    }
    if (outerBullCount > 0 && outerBullPenalty > 0) {
      details.add('25 x$outerBullCount: -$outerBullPenalty');
    }
    if (details.isEmpty) {
      details.add('Kein Bull-Malus in dieser Route.');
    }
    return details;
  }

  List<String> _narrowFieldDetails({
    required List<DartThrowResult> route,
    required int penalty,
  }) {
    final narrowFields = route.where(isNarrowField).toList();
    if (narrowFields.isEmpty || penalty == 0) {
      return <String>['Kein Malus fuer schmale Felder.'];
    }
    return <String>[
      ...List<String>.generate(route.length, (index) {
        final dartThrow = route[index];
        if (!isNarrowField(dartThrow)) {
          return '';
        }
        return '${dartThrow.label}: -${_singleNarrowFieldPenalty(dartThrow, isLast: index == route.length - 1, defaultPenalty: 150)}';
      }).where((detail) => detail.isNotEmpty),
      'Gesamtmalus: -$penalty',
    ];
  }

  List<String> _segmentFlowDetails(List<DartThrowResult> route) {
    final details = <String>[];
    for (var index = 1; index < route.length; index += 1) {
      final previous = route[index - 1];
      final current = route[index];
      if (previous.label == current.label) {
        details.add('${previous.label} -> ${current.label}: +18 gleiches Feld');
      } else if (previous.baseValue == current.baseValue) {
        details.add(
          '${previous.label} -> ${current.label}: +10 gleiches Segment',
        );
      } else if (isSingleOrOuterBull(previous) &&
          isSingleOrOuterBull(current)) {
        details.add(
          '${previous.label} -> ${current.label}: +4 ruhiger Single-Wechsel',
        );
      } else {
        details.add(
          '${previous.label} -> ${current.label}: -8 Wechsel ohne Flow-Bonus',
        );
      }
    }
    if (details.isEmpty) {
      details.add('Nur ein Dart, daher kein Segmentfluss-Anteil.');
    }
    return details;
  }

  int continuityScore(List<DartThrowResult> route) {
    var score = 0;

    for (var index = 1; index < route.length; index += 1) {
      final previous = route[index - 1];
      final current = route[index];

      if (previous.label == current.label) {
        score += 18;
        continue;
      }

      if (previous.baseValue == current.baseValue) {
        score += 10;
        continue;
      }

      if (isSingleOrOuterBull(previous) && isSingleOrOuterBull(current)) {
        score += 4;
      } else {
        score -= 8;
      }
    }

    return score;
  }

  int directDoubleLeaveBonus({
    required List<DartThrowResult> route,
    required int startScore,
  }) {
    if (route.isEmpty) {
      return 0;
    }

    if (route.last.isFinishDouble && !route.last.isBull) {
      var remaining = startScore;
      for (var index = 0; index < route.length - 1; index += 1) {
        remaining -= route[index].scoredPoints;
      }

      final finalDouble = route.last.baseValue * 2;
      if (remaining == finalDouble) {
        return route.length == 1 ? 34 : 24;
      }
    }

    if (route.length >= 2) {
      final first = route.first;
      final remainingAfterFirst = startScore - first.scoredPoints;
      if (!isNarrowField(first) &&
          remainingAfterFirst > 1 &&
          remainingAfterFirst <= 40 &&
          remainingAfterFirst.isEven) {
        return 28;
      }
    }

    return 0;
  }

  int singleOr25DoubleAccessBonus({
    required List<DartThrowResult> route,
    required int startScore,
  }) {
    if (route.isEmpty) {
      return 0;
    }

    var remaining = startScore;
    var bestBonus = 0;

    for (var index = 0; index < route.length - 1; index += 1) {
      final dartThrow = route[index];
      final isSingleOr25 =
          (!dartThrow.isDouble && !dartThrow.isTriple && !dartThrow.isBull) ||
          dartThrow.label == '25';
      if (!isSingleOr25) {
        break;
      }

      remaining -= dartThrow.scoredPoints;
      if (remaining == 50) {
        bestBonus = 50;
      } else if (remaining > 1 && remaining <= 40 && remaining.isEven) {
        bestBonus = 50;
      }
    }

    return bestBonus;
  }

  int doubleDoubleEndingBonus(List<DartThrowResult> route) {
    if (route.length < 2) {
      return 0;
    }

    final penultimate = route[route.length - 2];
    final last = route.last;
    if (penultimate.isDouble &&
        !penultimate.isBull &&
        last.isDouble &&
        !last.isBull) {
      return penultimate.baseValue == last.baseValue ? 52 : 36;
    }

    return 0;
  }

  int playStyleRouteAdjustment({
    required List<DartThrowResult> route,
    required int startScore,
    required int totalDarts,
    required CheckoutRequirement checkoutRequirement,
    required CheckoutPlayStyle playStyle,
    required int comfortBonus,
    required int robustnessBonus,
    required int narrowFieldPenalty,
  }) {
    if (route.isEmpty || playStyle == CheckoutPlayStyle.balanced) {
      return 0;
    }

    final first = route.first;
    final finalThrow = route.last;

    switch (playStyle) {
      case CheckoutPlayStyle.safe:
        return (comfortBonus ~/ 2) +
            (robustnessBonus ~/ 3) -
            (narrowFieldPenalty ~/ 4) -
            (route.length == 2 ? 40 : 0) +
            (first.isTriple ? 24 : 0);
      case CheckoutPlayStyle.aggressive:
        return (route.length == 2 ? 120 : 0) +
            (first.isTriple ? 36 : 0) +
            (robustnessBonus ~/ 6) +
            (narrowFieldPenalty ~/ 5) +
            (finalThrow.matchesCheckoutRequirement(checkoutRequirement)
                ? 18
                : 0);
      case CheckoutPlayStyle.balanced:
        return 0;
    }
  }

  int _targetPreference(
    int targetScore,
    CheckoutRequirement checkoutRequirement,
  ) {
    if (targetScore == 50) {
      return 24;
    }
    if (checkoutRequirement == CheckoutRequirement.singleOut &&
        targetScore == 1) {
      return 80;
    }
    if (targetScore > 1 && targetScore <= 40 && targetScore.isEven) {
      return 180 + doublePreference(rules.createDouble(targetScore ~/ 2));
    }
    if (targetScore > 40 && targetScore <= 170) {
      return 60;
    }
    if (targetScore == 1) {
      return -260;
    }
    return 0;
  }

  int doublePreference(DartThrowResult dartThrow) {
    if (!dartThrow.isFinishDouble) {
      return 0;
    }
    if (dartThrow.isBull) {
      return 25;
    }
    if (dartThrow.baseValue == 16) {
      return 36;
    }
    if (dartThrow.baseValue == 8) {
      return 32;
    }
    if (dartThrow.baseValue == 20 ||
        dartThrow.baseValue == 12 ||
        dartThrow.baseValue == 4) {
      return 30;
    }
    if (dartThrow.baseValue == 10 ||
        dartThrow.baseValue == 18 ||
        dartThrow.baseValue == 14 ||
        dartThrow.baseValue == 6 ||
        dartThrow.baseValue == 2) {
      return 28;
    }
    var halvingCount = 0;
    var value = dartThrow.baseValue;
    while (value > 0 && value.isEven) {
      halvingCount += 1;
      value ~/= 2;
    }

    return halvingCount * 12;
  }

  int _smallCheckoutSingleDoubleBonus({
    required List<DartThrowResult> route,
    required int startScore,
    required CheckoutRequirement checkoutRequirement,
  }) {
    if (checkoutRequirement != CheckoutRequirement.doubleOut ||
        startScore > 60 ||
        route.length != 2) {
      return 0;
    }
    final first = route.first;
    final last = route.last;
    final isPreferredSingleDouble =
        !first.isBull &&
        !first.isDouble &&
        !first.isTriple &&
        first.label != '25' &&
        last.isDouble &&
        !last.isBull;
    return isPreferredSingleDouble ? 600 : 0;
  }

  bool isNarrowField(DartThrowResult dartThrow) {
    return dartThrow.label == '25' ||
        dartThrow.isTriple ||
        dartThrow.isDouble ||
        dartThrow.isBull;
  }

  int _narrowFieldPenalty(
    List<DartThrowResult> route, {
    required int defaultPenalty,
  }) {
    var total = 0;
    for (var index = 0; index < route.length; index += 1) {
      final dartThrow = route[index];
      if (!isNarrowField(dartThrow)) {
        continue;
      }
      total += _singleNarrowFieldPenalty(
        dartThrow,
        isLast: index == route.length - 1,
        defaultPenalty: defaultPenalty,
      );
    }
    return total;
  }

  int _singleNarrowFieldPenalty(
    DartThrowResult dartThrow, {
    required bool isLast,
    required int defaultPenalty,
  }) {
    if (dartThrow.label == '25') {
      return 25;
    }
    if (dartThrow.isDouble && !dartThrow.isBull && !isLast) {
      return 175;
    }
    return 50;
  }

  bool isSingleOrOuterBull(DartThrowResult dartThrow) {
    return (!dartThrow.isDouble && !dartThrow.isTriple && !dartThrow.isBull) ||
        dartThrow.label == '25';
  }

  int setupThrowBias(DartThrowResult dartThrow) {
    if (dartThrow.isBull) {
      return -80;
    }
    if (dartThrow.label == '25') {
      return -10;
    }
    if (dartThrow.isDouble) {
      return -70;
    }
    if (dartThrow.isTriple) {
      return -24;
    }
    if (dartThrow.baseValue == 20) {
      return 42;
    }
    if (dartThrow.baseValue == 19) {
      return 28;
    }
    return 8;
  }

  int _outerBullPenaltyValue(int base, int preference) {
    return base + ((preference - 50) * 2);
  }

  int _bullPenaltyValue(int base, int preference, {int scale = 2}) {
    return base + ((preference - 50) * scale);
  }

  bool _isDeadScoreForCheckout(
    int score,
    CheckoutRequirement checkoutRequirement,
  ) {
    if (score < 0) {
      return true;
    }
    if (score != 1) {
      return false;
    }
    return checkoutRequirement != CheckoutRequirement.singleOut;
  }
}
