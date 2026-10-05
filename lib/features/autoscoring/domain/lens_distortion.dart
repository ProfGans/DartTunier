import 'dart:math';

/// Bounded radial model in image-width units. The optical centre is fixed;
/// board images alone cannot reliably estimate all intrinsic parameters.
class LensDistortion {
  const LensDistortion({this.k1 = 0, this.aspectRatio = 1});
  final double k1, aspectRatio;
  Point<double> distort(Point<double> point) {
    final x = point.x - .5, y = (point.y - .5) / aspectRatio;
    final scale = 1 + k1 * (x * x + y * y);
    return Point(.5 + x * scale, .5 + y * scale * aspectRatio);
  }

  Point<double> undistort(Point<double> point) {
    if (k1 == 0) return point;
    final x = point.x - .5,
        y = (point.y - .5) / aspectRatio,
        distortedRadius = sqrt(x * x + y * y);
    if (distortedRadius < 1e-12) return point;
    var radius = distortedRadius;
    for (var i = 0; i < 16; i++) {
      final error = radius * (1 + k1 * radius * radius) - distortedRadius;
      final derivative = 1 + 3 * k1 * radius * radius;
      if (derivative.abs() < 1e-9) break;
      radius -= error / derivative;
      if (error.abs() < 1e-12) break;
    }
    final scale = radius / distortedRadius;
    return Point(.5 + x * scale, .5 + y * scale * aspectRatio);
  }

  Map<String, Object> toJson() => {'k1': k1, 'aspectRatio': aspectRatio};
  factory LensDistortion.fromJson(Map<dynamic, dynamic> json) {
    final k = (json['k1'] as num).toDouble();
    final aspect = (json['aspectRatio'] as num).toDouble();
    final range = min(1.0, aspect * aspect);
    if (!k.isFinite ||
        k < -.2 * range ||
        k > .4 * range ||
        !aspect.isFinite ||
        aspect <= 0) {
      throw const FormatException('Ungültige Objektivkorrektur.');
    }
    return LensDistortion(k1: k, aspectRatio: aspect);
  }
}
