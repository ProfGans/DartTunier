import 'dart:math';
import 'board_geometry.dart';
import 'frame_detector.dart';

class DartTipObservation {
  const DartTipObservation(this.image, this.board, this.confidence);
  final BoardPoint image, board;
  final double confidence;
}

/// Recover a shaft endpoint, rather than treating the infinite axis as its tip.
/// Endpoints at the search boundary cannot count as physical board contact.
DartTipObservation? detectDartTip(
  GrayFrame before,
  GrayFrame after,
  BoardCalibration calibration,
  DartAxis axis,
  BoardPoint predicted,
) {
  final a = before.detail ?? before, b = after.detail ?? after;
  if (a.width != b.width || a.height != b.height || axis.confidence < .7) {
    return null;
  }
  final segment = calibration.imageAxis(axis);
  if (segment.length < 2) return null;
  final origin = calibration.lens.undistort(segment.first);
  final delta = calibration.lens.undistort(segment.last) - origin;
  final direction = delta * (1 / delta.magnitude);
  final points = <(double, BoardPoint)>[];
  final bounds = [
    for (var i = 0; i < 16; i++)
      calibration.unproject(
        predicted + Point(sin(i * pi / 8) * 60, cos(i * pi / 8) * 60),
      ),
  ];
  final left = max(1, (bounds.map((p) => p.x).reduce(min) * b.width).floor());
  final right = min(
    b.width - 2,
    (bounds.map((p) => p.x).reduce(max) * b.width).ceil(),
  );
  final top = max(1, (bounds.map((p) => p.y).reduce(min) * b.height).floor());
  final bottom = min(
    b.height - 2,
    (bounds.map((p) => p.y).reduce(max) * b.height).ceil(),
  );
  for (var y = top; y <= bottom; y++) {
    for (var x = left; x <= right; x++) {
      final index = y * b.width + x;
      if ((a.pixels[index] - b.pixels[index]).abs() < 24) continue;
      final raw = Point(x / (b.width - 1), y / (b.height - 1));
      final p = calibration.lens.undistort(raw), d = p - origin;
      if ((d.x * direction.y - d.y * direction.x).abs() > 2 / b.width) continue;
      final board = calibration.project(raw);
      if (board.magnitude > BoardGeometry.detectionRadius) continue;
      var neighbours = 0;
      for (var dy = -1; dy <= 1; dy++) {
        for (var dx = -1; dx <= 1; dx++) {
          final i = (y + dy) * b.width + x + dx;
          if ((a.pixels[i] - b.pixels[i]).abs() >= 24) neighbours++;
        }
      }
      if (neighbours >= 3) {
        points.add((d.x * direction.x + d.y * direction.y, raw));
      }
    }
  }
  if (points.length < 16) return null;
  points.sort((a, b) => a.$1.compareTo(b.$1));
  if ((points.last.$1 - points.first.$1) * b.width < 12) return null;
  final candidates = <DartTipObservation>[];
  for (final end in [points.first.$1, points.last.$1]) {
    final nearby = points
        .where((p) => (p.$1 - end).abs() <= 1.5 / b.width)
        .toList();
    final image = Point(
      nearby.fold<double>(0, (s, p) => s + p.$2.x) / nearby.length,
      nearby.fold<double>(0, (s, p) => s + p.$2.y) / nearby.length,
    );
    final board = calibration.project(image);
    if (board.magnitude >= 227 || board.distanceTo(predicted) > 25) continue;
    candidates.add(DartTipObservation(image, board, axis.confidence));
  }
  candidates.sort(
    (a, b) =>
        a.board.distanceTo(predicted).compareTo(b.board.distanceTo(predicted)),
  );
  return candidates.isEmpty ? null : candidates.first;
}

class TipContactDecision {
  const TipContactDecision(
    this.hit,
    this.observations,
    this.confirmed, {
    this.reason = 'notEvaluated',
  });
  final FusedHit hit;
  final List<DartTipObservation?> observations;
  final bool confirmed;
  final String reason;
}

TipContactDecision refineTipContact(
  FusedHit provisional,
  List<GrayFrame> before,
  List<GrayFrame> after,
  List<BoardCalibration> calibrations,
  List<DartAxis?> axes,
) {
  final tips = [
    for (var i = 0; i < axes.length; i++)
      axes[i] == null
          ? null
          : detectDartTip(
              before[i],
              after[i],
              calibrations[i],
              axes[i]!,
              provisional.point,
            ),
  ];
  final valid = tips.whereType<DartTipObservation>().toList();
  if (valid.length < 2 ||
      valid.any((a) => valid.any((b) => a.board.distanceTo(b.board) > 4))) {
    return TipContactDecision(
      provisional,
      tips,
      false,
      reason: valid.length < 2 ? 'insufficientTipViews' : 'tipViewsDisagree',
    );
  }
  final point = Point(
    valid.fold<double>(0, (s, t) => s + t.board.x) / valid.length,
    valid.fold<double>(0, (s, t) => s + t.board.y) / valid.length,
  );
  if (point.distanceTo(provisional.point) > 12) {
    return TipContactDecision(
      provisional,
      tips,
      false,
      reason: 'movementTooLarge',
    );
  }
  // Two apparent endpoints can belong to reflections or the visible shaft
  // above the board. They must not overturn a consistent three-view or
  // independently high-confidence two-shaft wire decision without a third tip.
  if (valid.length < 3 &&
      (provisional.views == 3 ||
          axes.whereType<DartAxis>().where((a) => a.confidence >= .9).length >=
              2) &&
      provisional.residual <= 3 &&
      BoardGeometry.score(point).label !=
          BoardGeometry.score(provisional.point).label) {
    return TipContactDecision(
      provisional,
      tips,
      false,
      reason: 'wireCrossingRejected',
    );
  }
  final residual = sqrt(
    valid.fold<double>(0, (s, t) => s + pow(t.board.distanceTo(point), 2)) /
        valid.length,
  );
  return TipContactDecision(
    FusedHit(
      point,
      residual,
      valid.length,
      forcedDecision: provisional.forcedDecision || valid.length < 3,
    ),
    tips,
    true,
    reason: 'tipsAgree',
  );
}
