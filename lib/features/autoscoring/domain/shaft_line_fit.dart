import 'dart:math';
import 'board_geometry.dart';

/// RANSAC followed by a subpixel PCA fit in undistorted image coordinates.
DartAxis? fitShaftLine(
  List<BoardPoint> points,
  BoardCalibration calibration,
  int width,
  int height, {
  bool outerRimOnly = false,
  double minimumSupport = .45,
  double pixelTolerance = 2.5,
  double maximumThicknessRatio = .22,
}) {
  if (points.length < 12) return null;
  final random = Random(7301);
  final stride = max(1, (points.length / 1200).ceil());
  final sample = [for (var i = 0; i < points.length; i += stride) points[i]];
  List<BoardPoint> best = const [];
  final tolerance = pixelTolerance / max(width, height);
  for (var attempt = 0; attempt < 160; attempt++) {
    final a = sample[random.nextInt(sample.length)],
        b = sample[random.nextInt(sample.length)],
        d = b - a;
    if (d.magnitude < 12 / max(width, height)) continue;
    final inliers = sample
        .where(
          (p) =>
              ((p.x - a.x) * d.y - (p.y - a.y) * d.x).abs() / d.magnitude <=
              tolerance,
        )
        .toList();
    if (inliers.length > best.length) best = inliers;
  }
  if (best.length < 12 || best.length < sample.length * minimumSupport) {
    return null;
  }
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
  final disc = sqrt(pow(xx - yy, 2) + 4 * xy * xy),
      major = (xx + yy + disc) / 2,
      minor = (xx + yy - disc) / 2;
  if (major < .0001 || minor / max(major, 1e-9) > maximumThicknessRatio) {
    return null;
  }
  final angle = .5 * atan2(2 * xy, xx - yy),
      direction = Point(cos(angle) * .05, sin(angle) * .05);
  return DartAxis(
    calibration.project(calibration.lens.distort(mean - direction)),
    calibration.project(calibration.lens.distort(mean + direction)),
    outerRimOnly: outerRimOnly,
    confidence: (best.length / sample.length * (1 - minor / max(major, 1e-9)))
        .clamp(.1, 1),
  );
}
