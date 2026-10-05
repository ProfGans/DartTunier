import 'fixed_checkouts.dart';
import 'x01/x01_models.dart';
import 'x01/x01_rules.dart';

/// Personalizes suggestions without changing game rules or bot strategies.
class PreferredCheckouts {
  static String? normalizeDouble(String value) {
    final text = value.trim().toUpperCase().replaceAll(' ', '');
    if (text == 'BULL' || text == 'BULLSEYE' || text == 'D25') return 'BULL';
    final number = int.tryParse(
      text.startsWith('D') ? text.substring(1) : text,
    );
    return number != null && number >= 1 && number <= 20 ? 'D$number' : null;
  }

  static List<List<DartThrowResult>> routes(
    int score, {
    int dartsLeft = 3,
    CheckoutRequirement requirement = CheckoutRequirement.doubleOut,
    String favoriteDouble = '',
  }) {
    final standard = FixedCheckouts.routes(
      score,
      dartsLeft: dartsLeft,
      requirement: requirement,
    );
    final label = normalizeDouble(favoriteDouble);
    if (label == null ||
        dartsLeft < 1 ||
        dartsLeft > 3 ||
        score < 2 ||
        score > 180) {
      return standard;
    }
    final throws = const X01Rules()
        .buildAllThrows()
        .where((d) => !d.isMiss && d.scoredPoints > 0)
        .toList();
    final finish = throws.where((d) => d.label == label).firstOrNull;
    if (finish == null || !finish.matchesCheckoutRequirement(requirement)) {
      return standard;
    }
    final preferred = <List<DartThrowResult>>[];
    void search(int remaining, List<DartThrowResult> prefix) {
      if (remaining == finish.scoredPoints) preferred.add([...prefix, finish]);
      if (prefix.length >= dartsLeft - 1) return;
      for (final dart in throws) {
        final rest = remaining - dart.scoredPoints;
        // Every prefix leaves the finishing double on the board.
        if (rest >= finish.scoredPoints) search(rest, [...prefix, dart]);
      }
    }

    search(score, []);
    if (preferred.isEmpty) return standard;
    preferred.sort((a, b) {
      final length = a.length.compareTo(b.length);
      if (length != 0) return length;
      for (var i = 0; i < a.length; i++) {
        final points = b[i].scoredPoints.compareTo(a[i].scoredPoints);
        if (points != 0) return points;
      }
      return a
          .map((d) => d.label)
          .join('/')
          .compareTo(b.map((d) => d.label).join('/'));
    });
    final seen = <String>{};
    return [
      for (final route in [preferred.first, ...standard])
        if (seen.add(route.map((d) => d.label).join('/'))) route,
    ].take(5).toList();
  }
}
