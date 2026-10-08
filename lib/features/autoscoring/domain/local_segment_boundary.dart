import 'dart:math';
import 'board_geometry.dart';
import 'frame_detector.dart';
import 'dart_tip_detection.dart';

class LocalSegmentBoundary {
  const LocalSegmentBoundary(this.offset, this.spread, this.samples);
  final double offset, spread;
  final int samples;
  Map<String, Object?> toJson() => {
    'offsetMillimetres': offset,
    'spreadMillimetres': spread,
    'samples': samples,
  };
}

class LocalSegmentContactDecision {
  const LocalSegmentContactDecision(this.hit, this.metrics);
  final FusedHit hit;
  final Map<String, Object?> metrics;
}

LocalSegmentContactDecision refineLocalSegmentContact(
  FusedHit provisional,
  List<GrayFrame> before,
  List<GrayFrame> after,
  List<GrayFrame> empty,
  List<BoardCalibration> calibrations,
  List<DartAxis?> axes,
  List<DartTipObservation?> tips,
) {
  final metrics = <String, Object?>{'applied': false};
  LocalSegmentContactDecision unchanged(String reason) {
    metrics['reason'] = reason;
    return LocalSegmentContactDecision(provisional, metrics);
  }

  final point = provisional.point;
  if (!BoardGeometry.nearWire(point, tolerance: 3) ||
      [
        6.35,
        15.9,
        99.0,
        107.0,
        162.0,
        170.0,
      ].any((r) => (point.magnitude - r).abs() < 3)) {
    return unchanged('notSegmentBoundary');
  }
  final originalScore = BoardGeometry.score(point);
  final candidates = tips
      .whereType<DartTipObservation>()
      .where(
        (t) =>
            t.confidence >= .9 &&
            t.board.distanceTo(point) <= 4 &&
            BoardGeometry.score(t.board).baseValue != originalScore.baseValue &&
            BoardGeometry.score(t.board).isDouble == originalScore.isDouble &&
            BoardGeometry.score(t.board).isTriple == originalScore.isTriple,
      )
      .toList();
  if (candidates.length != 1) return unchanged('noUniqueNearbyEndpoint');
  final candidate = candidates.single.board;
  final angle = atan2(point.x, -point.y);
  final boundary = ((angle - pi / 20) / (pi / 10)).round() * pi / 10 + pi / 20;
  final tangent = Point(cos(boundary), sin(boundary));
  double signed(BoardPoint p) => p.x * tangent.x + p.y * tangent.y;
  final wires = [
    for (var i = 0; i < calibrations.length; i++)
      measureLocalSegmentBoundary(empty[i], calibrations[i], point),
  ];
  metrics['wires'] = [for (final wire in wires) wire?.toJson()];
  final support = <int>[];
  for (var i = 0; i < wires.length; i++) {
    final wire = wires[i];
    if (wire == null) continue;
    final newSide = signed(candidate) - wire.offset;
    // The nominal estimate can already be on the correct side of the measured
    // wire: small calibration offsets must not veto a visible contact there.
    // Require the new contact to lie unambiguously in its proposed sector.
    final margin = max(.25, wire.spread * 2);
    if (newSide * signed(candidate) <= 0 || newSide.abs() < margin) {
      continue;
    }
    final axis = axes[i];
    if (axis == null ||
        (axis.a * candidate.x + axis.b * candidate.y + axis.c).abs() > 3) {
      continue;
    }
    final count = localContactChangeCount(
      before[i],
      after[i],
      calibrations[i],
      candidate,
    );
    if (count >= 6) support.add(i);
  }
  metrics['supportingCameras'] = support;
  metrics['candidate'] = {
    'xMillimetres': candidate.x,
    'yMillimetres': candidate.y,
  };
  if (support.length < 2) return unchanged('insufficientLocalContactSupport');
  metrics['applied'] = true;
  metrics['reason'] = 'localEndpointAndWireAgreement';
  return LocalSegmentContactDecision(
    FusedHit(
      candidate,
      provisional.residual,
      provisional.views,
      forcedDecision: true,
    ),
    metrics,
  );
}

int localContactChangeCount(
  GrayFrame before,
  GrayFrame after,
  BoardCalibration calibration,
  BoardPoint point,
) {
  final a = before.detail, b = after.detail;
  if (a == null || b == null || a.width != b.width || a.height != b.height) {
    return 0;
  }
  final bounds = [
    for (var i = 0; i < 8; i++)
      calibration.unproject(
        point + Point(sin(i * pi / 4) * 2.5, cos(i * pi / 4) * 2.5),
      ),
  ];
  final left = max(
    1,
    (bounds.map((p) => p.x).reduce(min) * (b.width - 1)).floor(),
  );
  final right = min(
    b.width - 2,
    (bounds.map((p) => p.x).reduce(max) * (b.width - 1)).ceil(),
  );
  final top = max(
    1,
    (bounds.map((p) => p.y).reduce(min) * (b.height - 1)).floor(),
  );
  final bottom = min(
    b.height - 2,
    (bounds.map((p) => p.y).reduce(max) * (b.height - 1)).ceil(),
  );
  var count = 0;
  for (var y = top; y <= bottom; y++) {
    for (var x = left; x <= right; x++) {
      final index = y * b.width + x;
      if ((a.pixels[index] - b.pixels[index]).abs() < 24 ||
          calibration
                  .project(Point(x / (b.width - 1), y / (b.height - 1)))
                  .distanceTo(point) >
              2.5) {
        continue;
      }
      var neighbours = 0;
      for (var dy = -1; dy <= 1; dy++) {
        for (var dx = -1; dx <= 1; dx++) {
          final j = (y + dy) * b.width + x + dx;
          if ((a.pixels[j] - b.pixels[j]).abs() >= 24) neighbours++;
        }
      }
      if (neighbours >= 3) count++;
    }
  }
  return count;
}

/// Measures a nearby black/white sector transition in an empty detail image.
/// Rings, missing detail, low contrast and inconsistent radial samples abstain.
LocalSegmentBoundary? measureLocalSegmentBoundary(
  GrayFrame empty,
  BoardCalibration calibration,
  BoardPoint point,
) {
  final frame = empty.detail;
  final radius = point.magnitude;
  if (frame == null || radius < 30 || radius > 150) {
    return null;
  }
  final angle = atan2(point.x, -point.y);
  final boundary = ((angle - pi / 20) / (pi / 10)).round() * pi / 10 + pi / 20;
  final radial = Point(sin(boundary), -cos(boundary));
  final tangent = Point(cos(boundary), sin(boundary));
  if ((point.x * tangent.x + point.y * tangent.y).abs() > 4) return null;
  double? sample(double r, double offset) {
    final p = calibration.unproject(radial * r + tangent * offset);
    final x = p.x * (frame.width - 1), y = p.y * (frame.height - 1);
    if (x < 1 || y < 1 || x >= frame.width - 2 || y >= frame.height - 2) {
      return null;
    }
    final ix = x.floor(),
        iy = y.floor(),
        dx = x - x.floor(),
        dy = y - y.floor();
    final i = iy * frame.width + ix;
    return frame.pixels[i] * (1 - dx) * (1 - dy) +
        frame.pixels[i + 1] * dx * (1 - dy) +
        frame.pixels[i + frame.width] * (1 - dx) * dy +
        frame.pixels[i + frame.width + 1] * dx * dy;
  }

  final offsets = <double>[];
  // Near the triple ring most of the short radial probes fall inside the
  // coloured ring and are skipped. Include the adjacent single fields so
  // there can still be four independent sector-edge measurements.
  final probes = (radius - 103).abs() < 8
      ? [-20.0, -16.0, -12.0, -8.0, -4.0, 0.0, 4.0, 8.0, 12.0, 16.0, 20.0]
      : [-8.0, -4.0, 0.0, 4.0, 8.0];
  for (final dr in probes) {
    final r = radius + dr;
    if (r >= 96 && r <= 110) continue;
    final left = sample(r, -7), right = sample(r, 7);
    if (left == null || right == null || (right - left).abs() < 60) continue;
    final midpoint = (left + right) / 2;
    final crossings = <double>[];
    for (var k = -20; k < 20; k++) {
      final x = k * .25;
      final a = sample(r, x), b = sample(r, x + .25);
      if (a == null || b == null) continue;
      if ((a - midpoint) * (right - left) <= 0 &&
          (b - midpoint) * (right - left) > 0) {
        final candidate = x + .25 * (midpoint - a) / (b - a);
        final before = sample(r, candidate - 2),
            after = sample(r, candidate + 2);
        if (before != null &&
            after != null &&
            (after - before) * (right - left) > 0 &&
            (after - before).abs() >= 50) {
          crossings.add(candidate);
        }
      }
    }
    if (crossings.length == 1) offsets.add(crossings.single);
  }
  if (offsets.length < 4) return null;
  offsets.sort();
  final median = offsets[offsets.length ~/ 2];
  final spread = offsets.last - offsets.first;
  if (spread > 2 || median.abs() > 4) return null;
  return LocalSegmentBoundary(median, spread, offsets.length);
}
