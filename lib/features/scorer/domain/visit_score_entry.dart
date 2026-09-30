import 'x01/x01_models.dart';
import 'x01/x01_rules.dart';

/// Validates aggregate human input; does not invent individual dart hits.
class VisitScoreEntry {
  static const _rules = X01Rules();
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
