import 'x01/x01_models.dart';
import 'x01/x01_rules.dart';

/// Validates aggregate human input; does not invent individual dart hits.
class VisitScoreEntry {
  static const _rules = X01Rules();

  /// Maximum checkout opportunities on a legal route matching the entered
  /// total. A finish reached only after dart three is not an attempt yet.
  static int maxDoubleAttempts({
    required int score,
    required int points,
    int darts = 3,
    bool opened = true,
  }) {
    final memo = <(int, int, int, bool), int>{};
    final throws = _rules.buildAllThrows();
    int search(int rest, int total, int left, bool isOpen) {
      if (left == 0) return total == 0 ? 0 : -1;
      final key = (rest, total, left, isOpen);
      if (memo.containsKey(key)) return memo[key]!;
      var best = -1;
      final chance =
          isOpen && (rest == 50 || (rest >= 2 && rest <= 40 && rest.isEven));
      for (final dart in throws) {
        final nextOpen = isOpen || dart.isFinishDouble;
        final value = nextOpen ? dart.scoredPoints : 0;
        if (value > total) continue;
        final next = rest - value;
        if (next < 0 || next == 1) continue;
        int tail;
        if (next == 0) {
          if (left != 1 || total != value || !dart.isFinishDouble) continue;
          tail = 0;
        } else {
          tail = search(next, total - value, left - 1, nextOpen);
        }
        if (tail < 0) continue;
        final attempts = tail + ((chance || next == 0) ? 1 : 0);
        if (attempts > best) best = attempts;
      }
      return memo[key] = best;
    }

    final result = search(score, points, darts, opened);
    return result < 0 ? 0 : result;
  }

  static bool canFinish(
    int score,
    int darts,
    CheckoutRequirement out, {
    bool doubleIn = false,
  }) {
    if (score < 1 || score > 180 || darts < 1 || darts > 3) return false;
    final throws = _rules.buildAllThrows();
    bool search(int rest, int left, bool opened) {
      for (final dart in throws) {
        if (!opened && !dart.isFinishDouble) {
          if (left > 1 &&
              dart.scoredPoints == 0 &&
              search(rest, left - 1, false)) {
            return true;
          }
          continue;
        }
        final next = rest - dart.scoredPoints;
        if (next < 0 || (next == 1 && out != CheckoutRequirement.singleOut)) {
          continue;
        }
        if (left == 1) {
          if (next == 0 && dart.matchesCheckoutRequirement(out)) return true;
        } else if (next > 0 && search(next, left - 1, true)) {
          return true;
        }
      }
      return false;
    }

    return search(score, darts, !doubleIn);
  }

  static VisitResult evaluate({
    required int score,
    required int points,
    required StartRequirement start,
    required CheckoutRequirement out,
    required bool opened,
    int? checkoutDarts,
  }) {
    final needsOpening = start == StartRequirement.doubleIn && !opened;
    if (!_rules.isAchievableVisitScore(
      points,
      requireDoubleInStart: needsOpening,
    )) {
      throw ArgumentError(
        needsOpening
            ? 'Diese Aufnahme ist mit Double In in drei Darts nicht möglich.'
            : 'Diese Aufnahme ist mit drei Darts nicht möglich (0–180).',
      );
    }
    final rest = score - points;
    if (rest == 0 &&
        (checkoutDarts == null ||
            !canFinish(score, checkoutDarts, out, doubleIn: needsOpening))) {
      throw ArgumentError(
        'Checkout mit dieser Dartanzahl und In-/Out-Regel nicht möglich.',
      );
    }
    final bust =
        rest < 0 || (rest == 1 && out != CheckoutRequirement.singleOut);
    return VisitResult(
      throws: const [],
      scoredPoints: bust ? 0 : points,
      didBust: bust,
      remainingScore: bust ? score : rest,
      openedLeg: bust ? opened : (opened || !needsOpening || points > 0),
    );
  }
}
