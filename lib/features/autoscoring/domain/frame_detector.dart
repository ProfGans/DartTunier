import 'dart:math';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'board_geometry.dart';
import 'shaft_line_fit.dart';

class GrayFrame {
  const GrayFrame(
    this.width,
    this.height,
    this.pixels, {
    this.sourceAspectRatio,
    this.detail,
  });
  final int width, height;
  final Uint8List pixels;
  final double? sourceAspectRatio;

  /// Retained higher-resolution reference; the fast motion path stays 480px.
  final GrayFrame? detail;
}

GrayFrame decodeCameraFrame(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) throw StateError('Ungültiges Kamerabild.');
  final small = img.copyResize(decoded, width: min(480, decoded.width));
  GrayFrame gray(img.Image image, {GrayFrame? detail}) {
    final pixels = Uint8List(image.width * image.height);
    for (final p in image) {
      pixels[p.y * image.width + p.x] = (p.r * .299 + p.g * .587 + p.b * .114)
          .round();
    }
    return GrayFrame(
      image.width,
      image.height,
      pixels,
      sourceAspectRatio: decoded.width / decoded.height,
      detail: detail,
    );
  }

  final detail = decoded.width > 480
      ? gray(
          decoded.width <= 1280
              ? decoded
              : img.copyResize(
                  decoded,
                  width: 1280,
                  interpolation: img.Interpolation.average,
                ),
        )
      : null;
  return gray(small, detail: detail);
}

class FrameDetector {
  const FrameDetector();
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
        if ((reference.pixels[i] - current.pixels[i]).abs() < 30) continue;
        final p = Point(x / (current.width - 1), y / (current.height - 1));
        if (calibration.project(p).magnitude <= BoardGeometry.detectionRadius) {
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
                sin(a) * (nearPoint == null ? 230 : 80),
                -cos(a) * (nearPoint == null ? 230 : 80),
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
    DartAxis? excludedAxis,
  }) {
    if (reference.width != current.width ||
        reference.height != current.height) {
      return null;
    }
    final points = <BoardPoint>[];
    // Limit analysis to the convex board quadrilateral, slightly expanded.
    for (var y = 1; y < current.height - 1; y++) {
      for (var x = 1; x < current.width - 1; x++) {
        final i = y * current.width + x;
        if ((reference.pixels[i] - current.pixels[i]).abs() < 30) continue;
        final p = Point(x / (current.width - 1), y / (current.height - 1));
        final board = calibration.project(p);
        if (board.magnitude > radius) continue;
        if (excludedAxis != null && excludedAxis.distance(board) < 3) continue;
        var neighbours = 0;
        for (var dy = -1; dy <= 1; dy++) {
          for (var dx = -1; dx <= 1; dx++) {
            final j = (y + dy) * current.width + x + dx;
            if ((reference.pixels[j] - current.pixels[j]).abs() >= 30) {
              neighbours++;
            }
          }
        }
        // Overlapping shafts can leave only a one-pixel-wide new edge.
        // Keep connected edges while discarding isolated noise pixels.
        if (neighbours >= 3) points.add(calibration.lens.undistort(p));
      }
    }
    if (points.length < (excludedAxis == null ? 12 : 24) ||
        points.length > current.pixels.length * .06) {
      return null;
    }
    return fitShaftLine(
      points,
      calibration,
      current.width,
      current.height,
      outerRimOnly: outerRimOnly,
    );
  }
}
