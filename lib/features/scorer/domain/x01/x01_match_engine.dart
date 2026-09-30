import 'x01_models.dart';
import 'x01_rules.dart';

class VisitProgressState {
  const VisitProgressState({
    required this.scoredPoints,
    required this.didBust,
    required this.remainingScore,
    required this.openedLeg,
  });

  final int scoredPoints;
  final bool didBust;
  final int remainingScore;
  final bool openedLeg;
}

class X01MatchEngine {
  X01MatchEngine({X01Rules? rules}) : rules = rules ?? const X01Rules();

  final X01Rules rules;

  VisitResult evaluateVisit({
    required int currentScore,
    required List<DartThrowResult> throws,
    required StartRequirement startRequirement,
    required bool hasOpenedLeg,
    required CheckoutRequirement checkoutRequirement,
  }) {
    final wasOpenedBefore =
        hasOpenedLeg || startRequirement == StartRequirement.straightIn;
    var runningScore = 0;
    var openedLeg = wasOpenedBefore;

    for (final dart in throws) {
      if (!openedLeg) {
        if (!dart.matchesStartRequirement(startRequirement)) {
          continue;
        }
        openedLeg = true;
      }

      runningScore += dart.scoredPoints;
      if (rules.isBust(
        currentScore: currentScore,
        scoredPoints: runningScore,
        checkoutRequirement: checkoutRequirement,
        finishingThrow: dart,
      )) {
        return VisitResult(
          throws: throws,
          scoredPoints: 0,
          didBust: true,
          remainingScore: currentScore,
          openedLeg: wasOpenedBefore,
        );
      }
    }

    return VisitResult(
      throws: throws,
      scoredPoints: runningScore,
      didBust: false,
      remainingScore: rules.remainingAfterVisit(currentScore, runningScore),
      openedLeg: openedLeg,
    );
  }

  VisitProgressState evaluateThrowProgress({
    required int currentScore,
    required int scoredPointsBeforeThrow,
    required bool hasOpenedLegBeforeVisit,
    required bool openedLegBeforeThrow,
    required DartThrowResult dartThrow,
    required StartRequirement startRequirement,
    required CheckoutRequirement checkoutRequirement,
  }) {
    final wasOpenedBeforeVisit =
        hasOpenedLegBeforeVisit ||
        startRequirement == StartRequirement.straightIn;
    var openedLeg = openedLegBeforeThrow;
    var runningScore = scoredPointsBeforeThrow;

    if (!openedLeg) {
      if (!dartThrow.matchesStartRequirement(startRequirement)) {
        return VisitProgressState(
          scoredPoints: runningScore,
          didBust: false,
          remainingScore: rules.remainingAfterVisit(currentScore, runningScore),
          openedLeg: false,
        );
      }
      openedLeg = true;
    }

    runningScore += dartThrow.scoredPoints;
    if (rules.isBust(
      currentScore: currentScore,
      scoredPoints: runningScore,
      checkoutRequirement: checkoutRequirement,
      finishingThrow: dartThrow,
    )) {
      return VisitProgressState(
        scoredPoints: 0,
        didBust: true,
        remainingScore: currentScore,
        openedLeg: wasOpenedBeforeVisit,
      );
    }

    return VisitProgressState(
      scoredPoints: runningScore,
      didBust: false,
      remainingScore: rules.remainingAfterVisit(currentScore, runningScore),
      openedLeg: openedLeg,
    );
  }

  bool isWinningVisit({
    required int currentScore,
    required VisitResult visit,
    required CheckoutRequirement checkoutRequirement,
  }) {
    if (visit.didBust) {
      return false;
    }

    final finishingThrow = visit.throws.isNotEmpty ? visit.throws.last : null;
    return !rules.isBust(
          currentScore: currentScore,
          scoredPoints: visit.scoredPoints,
          checkoutRequirement: checkoutRequirement,
          finishingThrow: finishingThrow,
        ) &&
        visit.remainingScore == 0;
  }
}
