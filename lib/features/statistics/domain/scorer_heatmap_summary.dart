import 'dart:math' as math;
import '../../scorer/domain/scorer_hit.dart';

/// Physical distribution, independent of scoring rules and visit busts.
class ScorerHeatmapSummary {
  ScorerHeatmapSummary(List<ScorerHit> hits) {
    for (final hit in hits) {
      fields.update(hit.label, (n) => n + 1, ifAbsent: () => 1);
      x += hit.location.x;
      y += hit.location.y;
    }
    if (hits.isEmpty) return;
    x /= hits.length;
    y /= hits.length;
    spread = math.sqrt(
      hits.fold<double>(
            0,
            (sum, hit) =>
                sum +
                math.pow(hit.location.x - x, 2) +
                math.pow(hit.location.y - y, 2),
          ) /
          hits.length,
    );
  }
  final fields = <String, int>{};
  double x = 0, y = 0, spread = 0;
  List<MapEntry<String, int>> get ranked =>
      fields.entries.toList()..sort((a, b) {
        final frequency = b.value.compareTo(a.value);
        return frequency == 0 ? a.key.compareTo(b.key) : frequency;
      });
}
