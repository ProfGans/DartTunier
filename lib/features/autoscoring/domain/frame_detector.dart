import 'dart:math';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'board_geometry.dart';

class GrayFrame {
  const GrayFrame(
    this.width,
    this.height,
    this.pixels, {
    this.sourceAspectRatio,
  });
  final int width, height;
  final Uint8List pixels;
  final double? sourceAspectRatio;
}

GrayFrame decodeCameraFrame(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) throw StateError('Ungültiges Kamerabild.');
  final small = img.copyResize(decoded, width: min(480, decoded.width));
  final pixels = Uint8List(small.width * small.height);
  for (var y = 0; y < small.height; y++) {
    for (var x = 0; x < small.width; x++) {
      final p = small.getPixel(x, y);
      pixels[y * small.width + x] = (p.r * .299 + p.g * .587 + p.b * .114)
          .round();
    }
  }
  return GrayFrame(
    small.width,
    small.height,
    pixels,
    sourceAspectRatio: decoded.width / decoded.height,
  );
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
  ) =>
      _axis(reference, current, calibration, 190) ??
      _axis(
        reference,
        current,
        calibration,
        BoardGeometry.detectionRadius,
        outerRimOnly: true,
      );

  DartAxis? _axis(
    GrayFrame reference,
    GrayFrame current,
    BoardCalibration calibration,
    double radius, {
    bool outerRimOnly = false,
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
        if (neighbours >= 3) points.add(p);
      }
    }
    if (points.length < 12 || points.length > current.pixels.length * .06) {
      return null;
    }
    // Flights, reflections and moving neighbours must not drag the shaft axis.
    // Find a dominant narrow line first, then fit only its supporting pixels.
    final random = Random(7301);
    final stride = max(1, (points.length / 1200).ceil());
    final sample = [for (var i = 0; i < points.length; i += stride) points[i]];
    List<BoardPoint> best = const [];
    final tolerance = 2.5 / max(current.width, current.height);
    for (var attempt = 0; attempt < 160; attempt++) {
      final a = sample[random.nextInt(sample.length)];
      final b = sample[random.nextInt(sample.length)];
      final d = b - a;
      // Use a pixel-scale minimum: at 480px the old normalized threshold
      // rejected visible shaft fragments shorter than roughly 29 pixels.
      if (d.magnitude < 12 / max(current.width, current.height)) continue;
      final inliers = sample
          .where(
            (p) =>
                ((p.x - a.x) * d.y - (p.y - a.y) * d.x).abs() / d.magnitude <=
                tolerance,
          )
          .toList();
      if (inliers.length > best.length) best = inliers;
    }
    if (best.length < 12 || best.length < sample.length * .45) return null;
    // PCA in image space: perspective projection preserves a straight shaft.
    final mean = Point(
      best.fold<double>(0, (s, p) => s + p.x) / best.length,
      best.fold<double>(0, (s, p) => s + p.y) / best.length,
    );
    double xx = 0, xy = 0, yy = 0;
    for (final p in best) {
      final d = p - mean;
      xx += d.x * d.x;
      xy += d.x * d.y;
      yy += d.y * d.y;
    }
    final disc = sqrt(pow(xx - yy, 2) + 4 * xy * xy);
    final major = (xx + yy + disc) / 2, minor = (xx + yy - disc) / 2;
    if (major < .0001 || minor / max(major, 1e-9) > .22) return null;
    final angle = .5 * atan2(2 * xy, xx - yy);
    final direction = Point(cos(angle) * .05, sin(angle) * .05);
    return DartAxis(
      calibration.project(mean - direction),
      calibration.project(mean + direction),
      outerRimOnly: outerRimOnly,
      confidence: (best.length / sample.length * (1 - minor / max(major, 1e-9)))
          .clamp(.1, 1),
    );
  }
}
