import 'dart:math';
import 'package:image/image.dart' as img;
import 'board_geometry.dart';
import 'dart_tip_detection.dart';
import 'frame_detector.dart';
import 'local_segment_boundary.dart';

// Decode each immutable empty-board reference once. Weak keys release cached
// colour when a setup is recalibrated or the empty-board reference changes.
final _ringColour = Expando<img.Image>();

/// Ring decisions need two independent visible endpoints and measured edges.
LocalSegmentContactDecision refineLocalRingContact(
  FusedHit hit,
  List<GrayFrame> before,
  List<GrayFrame> current,
  List<GrayFrame> empty,
  List<BoardCalibration> calibrations,
  List<DartAxis?> axes,
  List<DartTipObservation?> tips,
) {
  final metrics = <String, Object?>{'applied': false};
  LocalSegmentContactDecision unchanged(String reason) {
    metrics['reason'] = reason;
    return LocalSegmentContactDecision(hit, metrics);
  }

  const rings = [99.0, 107.0, 162.0, 170.0];
  final nearby = rings
      .where((r) => (hit.point.magnitude - r).abs() <= 4)
      .toList();
  if (nearby.length != 1) return unchanged('notUniqueRingBoundary');
  final ring = nearby.single;
  final candidates = tips
      .whereType<DartTipObservation>()
      .where(
        (t) =>
            t.confidence >= .85 &&
            t.board.distanceTo(hit.point) <= 6 &&
            BoardGeometry.score(t.board).label !=
                BoardGeometry.score(hit.point).label,
      )
      .toList();
  if (candidates.length < 2 ||
      candidates.any(
        (a) => candidates.any((b) => a.board.distanceTo(b.board) > 4),
      )) {
    return unchanged('endpointsNotIndependentlyConfirmed');
  }
  if (hit.views == 3 && hit.residual <= 3 && candidates.length < 3) {
    final contradicted = List.generate(tips.length, (i) {
      final tip = tips[i];
      return tip != null &&
          candidates.every((t) => t.board.distanceTo(tip.board) > 12) &&
          localContactChangeCount(
                before[i],
                current[i],
                calibrations[i],
                hit.point,
              ) <
              6 &&
          localContactChangeCount(
                empty[i],
                before[i],
                calibrations[i],
                hit.point,
              ) >=
              6;
    }).any((v) => v);
    if (!contradicted) return unchanged('independentThreeViewIntersection');
    metrics['contradictedOccupiedView'] = true;
  }
  final candidate = Point(
    candidates.fold<double>(0, (s, t) => s + t.board.x) / candidates.length,
    candidates.fold<double>(0, (s, t) => s + t.board.y) / candidates.length,
  );
  if (BoardGeometry.score(hit.point * (120 / hit.point.magnitude)).baseValue !=
      BoardGeometry.score(candidate * (120 / candidate.magnitude)).baseValue) {
    return unchanged('sectorCrossingNeedsSegmentCheck');
  }
  if ((candidate.magnitude - ring) * (hit.point.magnitude - ring) >= 0) {
    return unchanged('notRingCrossing');
  }
  final supporting = <int>[], edges = <Object?>[], contacts = <int>[];
  for (var i = 0; i < calibrations.length; i++) {
    final edge = measureLocalRingEdge(
      empty[i],
      calibrations[i],
      hit.point,
      ring,
    );
    edges.add(edge);
    contacts.add(
      localContactChangeCount(
        before[i],
        current[i],
        calibrations[i],
        candidate,
      ),
    );
    final tip = tips[i];
    final endpointSupport =
        tip != null &&
        tip.confidence >= .85 &&
        tip.board.distanceTo(candidate) <= 2 &&
        axes[i] != null &&
        axes[i]!.distance(candidate) <= 3;
    if (edge == null || (!endpointSupport && contacts.last < 6)) {
      continue;
    }
    final newSide = candidate.magnitude - edge;
    final uncertainty = candidates
        .map((t) => t.board.distanceTo(candidate))
        .reduce(max);
    if (newSide * (candidate.magnitude - ring) > 0 &&
        newSide.abs() >= max(.5, uncertainty + .25) &&
        contacts.last >= (endpointSupport ? 4 : 6)) {
      supporting.add(i);
    }
  }
  metrics.addAll({
    'ringMillimetres': ring,
    'measuredEdgesMillimetres': edges,
    'newContactPixels': contacts,
    'supportingCameras': supporting,
  });
  if (supporting.length < 2) {
    return unchanged('insufficientMeasuredRingSupport');
  }
  metrics.addAll({'applied': true, 'reason': 'twoEndpointsAndMeasuredRing'});
  return LocalSegmentContactDecision(
    FusedHit(
      candidate,
      sqrt(
        candidates.fold<double>(
              0,
              (sum, tip) => sum + pow(tip.board.distanceTo(candidate), 2),
            ) /
            candidates.length,
      ),
      min(supporting.length, candidates.length),
      forcedDecision: true,
    ),
    metrics,
  );
}

double? measureLocalRingEdge(
  GrayFrame empty,
  BoardCalibration calibration,
  BoardPoint point,
  double radius,
) {
  final grey = _measureRingEdge(empty, calibration, point, radius, false);
  return grey ?? _measureRingEdge(empty, calibration, point, radius, true);
}

double? _measureRingEdge(
  GrayFrame empty,
  BoardCalibration calibration,
  BoardPoint point,
  double radius,
  bool colour,
) {
  final image = empty.detail;
  if (image == null) return null;
  img.Image? rgb;
  if (colour) {
    rgb = _ringColour[empty];
    if (rgb == null && empty.colorImage != null) {
      rgb = img.decodeImage(empty.colorImage!);
      if (rgb != null) _ringColour[empty] = rgb;
    }
    if (rgb == null) return null;
  }
  final angle = atan2(point.x, -point.y), offsets = <double>[];
  double? sample(double a, double r) {
    final p = calibration.unproject(Point(sin(a) * r, -cos(a) * r));
    if (colour) {
      final x = (p.x * (rgb!.width - 1)).round(),
          y = (p.y * (rgb.height - 1)).round();
      if (x < 1 || y < 1 || x >= rgb.width - 1 || y >= rgb.height - 1) {
        return null;
      }
      final pixel = rgb.getPixel(x, y);
      return (max(pixel.r, pixel.g) - pixel.b).toDouble();
    }
    final x = (p.x * (image.width - 1)).round(),
        y = (p.y * (image.height - 1)).round();
    if (x < 1 || y < 1 || x >= image.width - 1 || y >= image.height - 1) {
      return null;
    }
    return (image.pixels[y * image.width + x] +
            image.pixels[y * image.width + x - 1] +
            image.pixels[y * image.width + x + 1]) /
        3;
  }

  for (final da in [-.025, -.0125, 0.0, .0125, .025]) {
    final a = angle + da;
    final left = sample(a, radius - 3.5), right = sample(a, radius + 3.5);
    if (left == null || right == null || (right - left).abs() < 40) continue;
    final mid = (left + right) / 2, crossings = <double>[];
    for (var n = -10; n < 10; n++) {
      final r = radius + n * .25, v = sample(a, r), w = sample(a, r + .25);
      if (v == null || w == null) continue;
      if ((v - mid) * (right - left) <= 0 && (w - mid) * (right - left) > 0) {
        crossings.add(r + .25 * (mid - v) / (w - v));
      }
    }
    if (crossings.length == 1) offsets.add(crossings.single);
  }
  if (offsets.length < 4) return null;
  offsets.sort();
  if (offsets.last - offsets.first > 1.5 ||
      (offsets[offsets.length ~/ 2] - radius).abs() > 2) {
    return null;
  }
  return offsets[offsets.length ~/ 2];
}
