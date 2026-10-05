import 'dart:math';
import 'package:dart_tournament_manager/features/autoscoring/domain/board_geometry.dart';
import 'package:dart_tournament_manager/features/autoscoring/domain/shaft_line_fit.dart';
import 'package:dart_tournament_manager/features/autoscoring/domain/frame_detector.dart'
    show GrayFrame;

class LegacyFrameDetector {
  const LegacyFrameDetector({this.reuseEvidence = true});

  /// Disable reuse for equivalence checks and benchmarks of fresh captures.
  final bool reuseEvidence;
  static final _changes = Expando<_FrameChanges>();

  _FrameChanges _evidence(
    GrayFrame reference,
    GrayFrame current,
    BoardCalibration calibration,
  ) {
    final cached = reuseEvidence ? _changes[current] : null;
    if (cached != null &&
        identical(cached.reference.target, reference) &&
        identical(cached.calibration, calibration)) {
      return cached;
    }
    final evidence = _FrameChanges(reference, calibration);
    for (var y = 1; y < current.height - 1; y++) {
      for (var x = 1; x < current.width - 1; x++) {
        final index = y * current.width + x;
        final difference = (reference.pixels[index] - current.pixels[index])
            .abs();
        if (difference < 18) continue;
        final raw = Point(x / (current.width - 1), y / (current.height - 1));
        final board = calibration.project(raw);
        if (board.magnitude > BoardGeometry.detectionRadius) continue;
        final normal =
            difference >= 30 && _connectedChange(reference, current, x, y, 30);
        final dark =
            board.magnitude > 170 &&
            reference.pixels[index] < 80 &&
            _connectedChange(reference, current, x, y, 18);
        if (normal || dark) {
          evidence.points.add((
            board,
            calibration.lens.undistort(raw),
            normal,
            dark,
          ));
        }
      }
    }
    if (reuseEvidence) _changes[current] = evidence;
    return evidence;
  }

  List<BoardPoint> changeSamples(
    GrayFrame reference,
    GrayFrame current,
    BoardCalibration calibration,
  ) {
    if (reference.width != current.width ||
        reference.height != current.height) {
      return const [];
    }
    final points = <BoardPoint>[];
    for (var y = 1; y < current.height - 1; y += 3) {
      for (var x = 1; x < current.width - 1; x += 3) {
        final i = y * current.width + x;
        final difference = (reference.pixels[i] - current.pixels[i]).abs();
        if (difference < 18) continue;
        final p = Point(x / (current.width - 1), y / (current.height - 1));
        final radius = calibration.project(p).magnitude;
        if (radius <= BoardGeometry.detectionRadius &&
            (difference >= 30 ||
                (radius > 170 &&
                    reference.pixels[i] < 80 &&
                    _connectedChange(reference, current, x, y, 18)))) {
          points.add(p);
        }
      }
    }
    final stride = max(1, (points.length / 600).ceil());
    return [for (var i = 0; i < points.length; i += stride) points[i]];
  }

  double changedFraction(GrayFrame a, GrayFrame b, {int threshold = 25}) {
    if (a.width != b.width || a.height != b.height) return 1;
    var changed = 0;
    for (var i = 0; i < a.pixels.length; i++) {
      if ((a.pixels[i] - b.pixels[i]).abs() > threshold) changed++;
    }
    return changed / a.pixels.length;
  }

  DartAxis? axis(
    GrayFrame reference,
    GrayFrame current,
    BoardCalibration calibration,
  ) {
    final coarse =
        _axis(reference, current, calibration, 190) ??
        _shaftFallback(reference, current, calibration) ??
        _axis(
          reference,
          current,
          calibration,
          BoardGeometry.detectionRadius,
          outerRimOnly: true,
        ) ??
        _axis(
          reference,
          current,
          calibration,
          BoardGeometry.detectionRadius,
          outerRimOnly: true,
          darkRim: true,
        );
    return coarse == null
        ? null
        : _refineDetail(reference, current, calibration, coarse);
  }

  /// Distinct alternatives remain separate until cameras are compared.
  List<DartAxis> candidates(
    GrayFrame reference,
    GrayFrame current,
    BoardCalibration calibration, {
    DartAxis? primary,
  }) {
    primary ??= axis(reference, current, calibration);
    final result = <DartAxis>[?primary];
    final rim = _axis(
      reference,
      current,
      calibration,
      BoardGeometry.detectionRadius,
      outerRimOnly: true,
      darkRim: true,
    );
    if (rim != null &&
        rim.confidence >= .75 &&
        (primary == null ||
            (primary.a * rim.b - primary.b * rim.a).abs() >= .015 ||
            (primary.c - rim.c * (primary.a * rim.a + primary.b * rim.b).sign)
                    .abs() >=
                1)) {
      result.add(rim);
    }
    if (primary != null) {
      final secondary = _axis(
        reference,
        current,
        calibration,
        190,
        excludedAxis: primary,
      );
      if (secondary != null && secondary.confidence >= .75) {
        result.add(secondary);
      }
    }
    for (final radius in [160.0, 140.0, 100.0, 230.0]) {
      final alternative = _axis(
        reference,
        current,
        calibration,
        radius,
        outerRimOnly: radius > 190,
      );
      if (alternative == null || alternative.confidence < .65) continue;
      final refined = alternative;
      if (result.any(
        (a) =>
            (a.a * refined.b - a.b * refined.a).abs() < .015 &&
            (a.c - refined.c * (a.a * refined.a + a.b * refined.b).sign).abs() <
                1,
      )) {
        continue;
      }
      result.add(refined);
      if (result.length == 4) break;
    }
    return result;
  }

  DartAxis refineAxis(
    GrayFrame reference,
    GrayFrame current,
    BoardCalibration calibration,
    DartAxis axis, {
    BoardPoint? nearPoint,
  }) => _refineDetail(
    reference,
    current,
    calibration,
    axis,
    nearPoint: nearPoint,
  );

  DartAxis _refineDetail(
    GrayFrame reference,
    GrayFrame current,
    BoardCalibration calibration,
    DartAxis coarse, {
    BoardPoint? nearPoint,
  }) {
    final before = reference.detail, after = current.detail;
    if (before == null ||
        after == null ||
        before.width != after.width ||
        before.height != after.height) {
      return coarse;
    }
    final segment = calibration.imageAxis(coarse);
    if (segment.length < 2) return coarse;
    final points = <BoardPoint>[];
    // Scan only the bounding box of the predicted shaft in the board region.
    final boardSamples = [
      for (var a = 0.0; a < 2 * pi; a += pi / 20)
        calibration.unproject(
          (nearPoint ?? const Point(0.0, 0.0)) +
              Point(
                sin(a) * (nearPoint == null ? 230 : 35),
                -cos(a) * (nearPoint == null ? 230 : 35),
              ),
        ),
    ];
    final left = max(
          1,
          (boardSamples.map((p) => p.x).reduce(min) * after.width).floor(),
        ),
        right = min(
          after.width - 2,
          (boardSamples.map((p) => p.x).reduce(max) * after.width).ceil(),
        ),
        top = max(
          1,
          (boardSamples.map((p) => p.y).reduce(min) * after.height).floor(),
        ),
        bottom = min(
          after.height - 2,
          (boardSamples.map((p) => p.y).reduce(max) * after.height).ceil(),
        );
    final lineStart = calibration.lens.undistort(segment.first),
        direction = calibration.lens.undistort(segment.last) - lineStart;
    for (var y = top; y <= bottom; y++) {
      for (var x = left; x <= right; x++) {
        final index = y * after.width + x;
        if ((before.pixels[index] - after.pixels[index]).abs() < 30) continue;
        final raw = Point(x / (after.width - 1), y / (after.height - 1)),
            p = calibration.lens.undistort(raw);
        if (((p.x - lineStart.x) * direction.y -
                            (p.y - lineStart.y) * direction.x)
                        .abs() /
                    direction.magnitude >
                4 / 480 ||
            calibration.project(raw).magnitude > 230) {
          continue;
        }
        var neighbours = 0;
        for (var dy = -1; dy <= 1; dy++) {
          for (var dx = -1; dx <= 1; dx++) {
            final i = (y + dy) * after.width + x + dx;
            if ((before.pixels[i] - after.pixels[i]).abs() >= 30) neighbours++;
          }
        }
        if (neighbours >= 3) points.add(p);
      }
    }
    final fit = fitShaftLine(
      points,
      calibration,
      after.width,
      after.height,
      outerRimOnly: coarse.outerRimOnly,
      pixelTolerance: 1.5,
    );
    if (fit == null ||
        fit.confidence < .65 ||
        (fit.a * coarse.b - fit.b * coarse.a).abs() > .08) {
      return coarse;
    }
    return fit;
  }

  DartAxis? _shaftFallback(
    GrayFrame reference,
    GrayFrame current,
    BoardCalibration calibration,
  ) {
    // A flight or an overlapping neighbour can dominate the full-board change.
    // Recover only a strong connected shaft closer to the board centre; keep
    // successful full-board axes and the independent outer-rim pass unchanged.
    final shaft = _axis(reference, current, calibration, 100);
    return shaft != null && shaft.confidence >= .8 ? shaft : null;
  }

  DartAxis? _axis(
    GrayFrame reference,
    GrayFrame current,
    BoardCalibration calibration,
    double radius, {
    bool outerRimOnly = false,
    bool darkRim = false,
    DartAxis? excludedAxis,
  }) {
    if (reference.width != current.width ||
        reference.height != current.height) {
      return null;
    }
    final evidence = _evidence(reference, current, calibration);
    final key = (radius, outerRimOnly, darkRim);
    if (excludedAxis == null && evidence.axes.containsKey(key)) {
      return evidence.axes[key];
    }
    final points = <BoardPoint>[
      for (final point in evidence.points)
        if (point.$1.magnitude <= radius &&
            (darkRim ? point.$4 : point.$3) &&
            (excludedAxis == null || excludedAxis.distance(point.$1) >= 3))
          point.$2,
    ];
    if (points.length < (darkRim ? 48 : (excludedAxis == null ? 12 : 24)) ||
        points.length > current.pixels.length * .06) {
      return null;
    }
    final axis = fitShaftLine(
      points,
      calibration,
      current.width,
      current.height,
      outerRimOnly: outerRimOnly,
      minimumSupport: darkRim ? .95 : .45,
      maximumThicknessRatio: darkRim ? .025 : .22,
    );
    if (excludedAxis == null) evidence.axes[key] = axis;
    return axis;
  }

  bool _connectedChange(
    GrayFrame before,
    GrayFrame after,
    int x,
    int y,
    int threshold,
  ) {
    var neighbours = 0;
    for (var dy = -1; dy <= 1; dy++) {
      for (var dx = -1; dx <= 1; dx++) {
        final i = (y + dy) * after.width + x + dx;
        if ((before.pixels[i] - after.pixels[i]).abs() >= threshold) {
          neighbours++;
        }
      }
    }
    return neighbours >= 3;
  }
}

// Weakly keyed by current frame: changing the reference or calibration always
// invalidates the evidence. It cannot accumulate across camera captures.
class _FrameChanges {
  _FrameChanges(GrayFrame reference, this.calibration)
    : reference = WeakReference(reference);
  final WeakReference<GrayFrame> reference;
  final BoardCalibration calibration;
  final points = <(BoardPoint, BoardPoint, bool, bool)>[];
  final axes = <(double, bool, bool), DartAxis?>{};
}
