import 'dart:math';

class VerificationSummary {
  const VerificationSummary(this.attempts, this.correct, this.incorrect);
  final int attempts, correct, incorrect;
  int get reviewed => correct + incorrect;
  double? get accuracyPercent =>
      reviewed == 0 ? null : 100 * correct / reviewed;

  /// Exact one-sided 95% Clopper-Pearson lower limit via a binomial tail.
  double get lowerBoundPercent {
    if (correct == 0 || reviewed == 0) return 0;
    var logChoose = 0.0;
    for (var i = 1; i <= correct; i++) {
      logChoose += log((reviewed - correct + i) / i);
    }
    double tail(double p) {
      var term = exp(logChoose + correct * log(p) + incorrect * log(1 - p));
      var total = term;
      for (var k = correct; k < reviewed; k++) {
        term *= (reviewed - k) / (k + 1) * p / (1 - p);
        total += term;
      }
      return total;
    }

    var low = 0.0, high = correct / reviewed;
    for (var i = 0; i < 45; i++) {
      final middle = (low + high) / 2;
      if (tail(middle) < .05) {
        low = middle;
      } else {
        high = middle;
      }
    }
    return (low + high) * 50;
  }

  bool get supportsTarget =>
      attempts == reviewed && reviewed >= 600 && lowerBoundPercent >= 99.5;
}
