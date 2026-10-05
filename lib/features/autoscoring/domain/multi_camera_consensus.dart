import 'board_geometry.dart';

class CameraConsensus {
  const CameraConsensus(this.hit, this.axes, this.alternativesUsed);
  final FusedHit? hit;
  final List<DartAxis?> axes;
  final bool alternativesUsed;
}

/// At most one observation per camera. Extra lines in one image never count
/// as independent views. Ambiguous combinations preserve the primary result.
CameraConsensus chooseCameraConsensus(List<List<DartAxis>> cameras) {
  final primary = [for (final c in cameras) c.isEmpty ? null : c.first];
  final baseline = fuseAxes(primary.whereType<DartAxis>().toList());
  if (cameras.length != 3) return CameraConsensus(baseline, primary, false);
  // A fit supported only by changes on the black rim must not displace two
  // strong inner-board shaft observations by centimetres. Generic conflicting
  // cameras remain ambiguous; this exception requires the rim-specific flag.
  if (baseline == null && primary.whereType<DartAxis>().length == 3) {
    final inner = primary
        .whereType<DartAxis>()
        .where((a) => !a.outerRimOnly)
        .toList();
    final rim = primary
        .whereType<DartAxis>()
        .where((a) => a.outerRimOnly)
        .toList();
    if (inner.length == 2 &&
        rim.length == 1 &&
        inner.every((a) => a.confidence >= .85)) {
      final pair = fuseAxes(inner);
      if (pair != null &&
          pair.point.magnitude < 160 &&
          rim.single.distance(pair.point) > 20) {
        return CameraConsensus(
          FusedHit(pair.point, pair.residual, 2, forcedDecision: true),
          [for (final a in primary) a?.outerRimOnly == true ? null : a],
          true,
        );
      }
    }
  }
  final combinations = <CameraConsensus>[];
  void visit(int index, List<DartAxis?> chosen) {
    if (index < cameras.length) {
      for (final axis
          in cameras[index].isEmpty ? <DartAxis?>[null] : cameras[index]) {
        visit(index + 1, [...chosen, axis]);
      }
      return;
    }
    final axes = chosen.whereType<DartAxis>().toList();
    if (axes.length < 2 || axes.any((a) => a.confidence < .65)) return;
    final hit = fuseAxes(axes);
    if (hit == null || hit.residual > 3) return;
    combinations.add(
      CameraConsensus(
        hit,
        chosen,
        List.generate(3, (i) => chosen[i] != primary[i]).any((v) => v),
      ),
    );
  }

  visit(0, []);
  double quality(CameraConsensus c) =>
      c.hit!.views * 2 +
      c.axes.whereType<DartAxis>().fold<double>(0, (s, a) => s + a.confidence) /
          c.hit!.views -
      c.hit!.residual / 8;
  combinations.sort((a, b) => quality(b).compareTo(quality(a)));
  if (combinations.isEmpty) return CameraConsensus(baseline, primary, false);
  final best = combinations.first;
  final hit = best.hit!;
  if (baseline != null &&
      ((baseline.views == 3 && (baseline.residual <= 3 || hit.residual > 2)) ||
          hit.views < 3 ||
          hit.point.distanceTo(baseline.point) > 12 ||
          best.axes.whereType<DartAxis>().any((a) => a.confidence < .75))) {
    return CameraConsensus(baseline, primary, false);
  }
  final ambiguous = combinations
      .skip(1)
      .any(
        (c) =>
            quality(best) - quality(c) < .08 &&
            c.hit!.point.distanceTo(hit.point) > 5,
      );
  if (ambiguous) return CameraConsensus(baseline, primary, false);
  return CameraConsensus(
    FusedHit(
      hit.point,
      hit.residual,
      hit.views,
      forcedDecision: hit.forcedDecision || best.alternativesUsed,
    ),
    best.axes,
    best.alternativesUsed,
  );
}
