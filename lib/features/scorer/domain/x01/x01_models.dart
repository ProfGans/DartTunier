enum CheckoutRequirement { singleOut, doubleOut, masterOut }

enum StartRequirement { straightIn, doubleIn }

enum CheckoutPlayStyle { safe, balanced, aggressive }

enum MatchMode { legs, sets }

enum ThrowMultiplier { single, doubleValue, triple }

class BotProfile {
  const BotProfile({
    required this.skill,
    required this.finishingSkill,
    this.radiusCalibrationPercent = 92,
    this.simulationSpreadPercent = 115,
  });

  final int skill;
  final int finishingSkill;
  final int radiusCalibrationPercent;
  final int simulationSpreadPercent;
}

class MatchConfig {
  const MatchConfig({
    required this.startScore,
    required this.mode,
    this.startRequirement = StartRequirement.straightIn,
    required this.checkoutRequirement,
    required this.legsToWin,
    this.setsToWin = 1,
    this.legsPerSet = 1,
  });

  final int startScore;
  final MatchMode mode;
  final StartRequirement startRequirement;
  final CheckoutRequirement checkoutRequirement;
  final int legsToWin;
  final int setsToWin;
  final int legsPerSet;
}

class DartThrowResult {
  const DartThrowResult({
    required this.label,
    required this.baseValue,
    required this.scoredPoints,
    required this.isDouble,
    required this.isTriple,
    this.isBull = false,
    this.isMiss = false,
  });

  final String label;
  final int baseValue;
  final int scoredPoints;
  final bool isDouble;
  final bool isTriple;
  final bool isBull;
  final bool isMiss;

  bool get isFinishDouble => isDouble || isBull;
  bool get isFinishSingle => !isDouble && !isTriple && !isBull;
  bool get isFinishTriple => isTriple;

  bool matchesStartRequirement(StartRequirement requirement) {
    switch (requirement) {
      case StartRequirement.straightIn:
        return true;
      case StartRequirement.doubleIn:
        return isFinishDouble;
    }
  }

  bool matchesCheckoutRequirement(CheckoutRequirement requirement) {
    switch (requirement) {
      case CheckoutRequirement.singleOut:
        return !isMiss;
      case CheckoutRequirement.doubleOut:
        return isFinishDouble;
      case CheckoutRequirement.masterOut:
        return isFinishDouble || isFinishTriple;
    }
  }
}

class VisitResult {
  const VisitResult({
    required this.throws,
    required this.scoredPoints,
    required this.didBust,
    required this.remainingScore,
    required this.openedLeg,
  });

  final List<DartThrowResult> throws;
  final int scoredPoints;
  final bool didBust;
  final int remainingScore;
  final bool openedLeg;
}

class CheckoutPlan {
  const CheckoutPlan({required this.throws});

  final List<DartThrowResult> throws;

  bool get isEmpty => throws.isEmpty;
}
