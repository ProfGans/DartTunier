import 'dart:math' as math;
import '../../scorer/domain/scorer_hit.dart';
import '../../scorer/domain/x01/x01_rules.dart';

class HeatmapTargetResult {
  HeatmapTargetResult(this.target, this.hits);
  final String target;
  final List<ScorerHit> hits;
  int get successes => hits.where((h) => h.label == target).length;
  double get percent => hits.isEmpty ? 0 : successes * 100 / hits.length;
  ({double x, double y})? get center {
    if (target == 'BULL') return (x: 0, y: 0);
    final n = int.tryParse(target.replaceFirst(RegExp(r'^[DT]'), ''));
    final index = X01Rules.wheel.indexOf(n ?? -1);
    final radius = target.startsWith('D')
        ? 166.0
        : target.startsWith('T')
        ? 103.0
        : null;
    if (index < 0 || radius == null) return null;
    final angle = index * math.pi / 10;
    return (x: math.sin(angle) * radius, y: -math.cos(angle) * radius);
  }

  double? get meanTargetDistance {
    final c = center;
    if (c == null || hits.isEmpty) return null;
    return hits.fold<double>(
          0,
          (sum, h) =>
              sum +
              math.sqrt(
                math.pow(h.location.x - c.x, 2) +
                    math.pow(h.location.y - c.y, 2),
              ),
        ) /
        hits.length;
  }

  int get neighborHits {
    final n = int.tryParse(target.replaceFirst(RegExp(r'^[DT]'), ''));
    final index = X01Rules.wheel.indexOf(n ?? -1);
    if (index < 0) return 0;
    final neighbors = {
      X01Rules.wheel[(index + 19) % 20],
      X01Rules.wheel[(index + 1) % 20],
    };
    return hits
        .where(
          (h) => neighbors.contains(
            int.tryParse(h.label.replaceFirst(RegExp(r'^[DT]'), '')),
          ),
        )
        .length;
  }
}

class HeatmapAnalysis {
  static List<HeatmapTargetResult> targets(List<ScorerHit> hits) {
    final grouped = <String, List<ScorerHit>>{};
    for (final h in hits) {
      if (h.targetLabel == null) continue;
      grouped.putIfAbsent(h.targetLabel!, () => []).add(h);
    }
    return [
      for (final entry in grouped.entries)
        HeatmapTargetResult(entry.key, List.unmodifiable(entry.value)),
    ]..sort((a, b) => b.hits.length.compareTo(a.hits.length));
  }

  static List<ScorerHit> filter(
    List<ScorerHit> hits, {
    String? target,
    String? field,
    int? dart,
    int? visit,
    String area = 'Alle',
  }) => hits
      .where(
        (h) =>
            (target == null || h.targetLabel == target) &&
            (field == null || h.label == field) &&
            (dart == null || h.dartInVisit == dart) &&
            (visit == null || h.visitIndex == visit) &&
            (area != 'Scoring' || h.checkoutAttempt != true) &&
            (area != 'Checkout' || h.checkoutAttempt == true) &&
            (area != 'Training' || h.targetLabel != null),
      )
      .toList();
}
