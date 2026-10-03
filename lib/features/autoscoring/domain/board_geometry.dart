import 'dart:math';
import '../../scorer/domain/x01/x01_models.dart';
import '../../scorer/domain/x01/x01_rules.dart';

/// Board coordinates are millimetres, bull at (0,0), 20 at negative y.
typedef BoardPoint = Point<double>;

class BoardGeometry {
  /// Scoring ends at 170 mm; include the black outer rim for stuck misses.
  static const detectionRadius = 230.0;
  static const flatViewExtent = 240.0;
  static const flatViewDiameter = flatViewExtent * 2;
  static DartThrowResult score(BoardPoint point) {
    final r = point.magnitude;
    const rules = X01Rules();
    if (r > 170) return rules.createMiss();
    if (r <= 6.35) return rules.createBull();
    if (r <= 15.9) return rules.createOuterBull();
    final angle = (atan2(point.x, -point.y) + 2 * pi) % (2 * pi);
    final sector = ((angle + pi / 20) / (pi / 10)).floor() % 20;
    final value = X01Rules.wheel[sector];
    if (r >= 162) return rules.createDouble(value);
    if (r >= 99 && r <= 107) return rules.createTriple(value);
    return rules.createSingle(value);
  }

  static bool nearWire(BoardPoint p, {double tolerance = 2}) {
    final r = p.magnitude;
    if ([
      6.35,
      15.9,
      99.0,
      107.0,
      162.0,
      170.0,
    ].any((wire) => (r - wire).abs() <= tolerance)) {
      return true;
    }
    if (r <= 15.9 || r > 170) return false;
    final a = (atan2(p.x, -p.y) + 2 * pi + pi / 20) % (pi / 10);
    return r * sin(min(a, pi / 10 - a)) <= tolerance;
  }
}

/// Four points: outer double at the centres of 20, 6, 3, 11 (clockwise).
class BoardCalibration {
  BoardCalibration(List<BoardPoint> points)
    : points = List.unmodifiable(points) {
    if (points.length != 4) {
      throw ArgumentError('Vier Kalibrierpunkte benötigt.');
    }
    const target = [
      Point(0.0, -170.0),
      Point(170.0, 0.0),
      Point(0.0, 170.0),
      Point(-170.0, 0.0),
    ];
    final equations = <List<double>>[];
    for (var i = 0; i < 4; i++) {
      final p = points[i], q = target[i];
      equations.add([p.x, p.y, 1, 0, 0, 0, -q.x * p.x, -q.x * p.y, q.x]);
      equations.add([0, 0, 0, p.x, p.y, 1, -q.y * p.x, -q.y * p.y, q.y]);
    }
    for (var col = 0; col < 8; col++) {
      var pivot = col;
      for (var row = col + 1; row < 8; row++) {
        if (equations[row][col].abs() > equations[pivot][col].abs()) {
          pivot = row;
        }
      }
      final swap = equations[col];
      equations[col] = equations[pivot];
      equations[pivot] = swap;
      final divisor = equations[col][col];
      if (divisor.abs() < 1e-9) {
        throw ArgumentError(
          'Kalibrierpunkte liegen zu dicht oder auf einer Linie.',
        );
      }
      for (var j = col; j <= 8; j++) {
        equations[col][j] /= divisor;
      }
      for (var row = 0; row < 8; row++) {
        if (row == col) continue;
        final factor = equations[row][col];
        for (var j = col; j <= 8; j++) {
          equations[row][j] -= factor * equations[col][j];
        }
      }
    }
    _h = [for (var i = 0; i < 8; i++) equations[i][8]];
    // Reject crossed, non-convex and nearly collapsed quadrilaterals.
    final turns = <double>[];
    for (var i = 0; i < 4; i++) {
      final a = points[(i + 1) % 4] - points[i];
      final b = points[(i + 2) % 4] - points[(i + 1) % 4];
      turns.add(a.x * b.y - a.y * b.x);
    }
    if (turns.any((t) => t.abs() < .002) ||
        !(turns.every((t) => t > 0) || turns.every((t) => t < 0))) {
      throw ArgumentError(
        'Punkte müssen den Double-Ring in richtiger Reihenfolge umschließen.',
      );
    }
  }
  final List<BoardPoint> points;
  late final List<double> _h;
  BoardPoint project(BoardPoint p) {
    final d = _h[6] * p.x + _h[7] * p.y + 1;
    if (d.abs() < 1e-9) throw StateError('Punkt außerhalb der Kalibrierung.');
    return Point(
      (_h[0] * p.x + _h[1] * p.y + _h[2]) / d,
      (_h[3] * p.x + _h[4] * p.y + _h[5]) / d,
    );
  }

  /// Inverse homography for drawing millimetre-space observations on the image.
  BoardPoint unproject(BoardPoint q) {
    final a = _h[0] - q.x * _h[6], b = _h[1] - q.x * _h[7];
    final c = _h[3] - q.y * _h[6], d = _h[4] - q.y * _h[7];
    final x = q.x - _h[2], y = q.y - _h[5], det = a * d - b * c;
    if (det.abs() < 1e-9) {
      throw StateError('Punkt außerhalb der Kamera-Projektion.');
    }
    return Point((x * d - b * y) / det, (a * y - x * c) / det);
  }

  List<BoardPoint> imageAxis(DartAxis axis) {
    final a = axis.a * _h[0] + axis.b * _h[3] + axis.c * _h[6];
    final b = axis.a * _h[1] + axis.b * _h[4] + axis.c * _h[7];
    final c = axis.a * _h[2] + axis.b * _h[5] + axis.c;
    final points = <BoardPoint>[];
    void add(double x, double y) {
      final p = Point(x, y);
      if (x >= 0 &&
          x <= 1 &&
          y >= 0 &&
          y <= 1 &&
          points.every((q) => q.distanceTo(p) > 1e-8)) {
        points.add(p);
      }
    }

    if (b.abs() > 1e-9) {
      add(0, -c / b);
      add(1, -(a + c) / b);
    }
    if (a.abs() > 1e-9) {
      add(-c / a, 0);
      add(-(b + c) / a, 1);
    }
    return points;
  }
}

class DartAxis {
  DartAxis(
    BoardPoint start,
    BoardPoint end, {
    this.confidence = 1,
    this.outerRimOnly = false,
  }) {
    if (!confidence.isFinite || confidence <= 0 || confidence > 1) {
      throw ArgumentError('Ungültige Achsenqualität.');
    }
    final length = start.distanceTo(end);
    if (length < 1e-6) throw ArgumentError('Dartachse zu kurz.');
    a = (start.y - end.y) / length;
    b = (end.x - start.x) / length;
    c = -(a * start.x + b * start.y);
  }
  late final double a, b, c;
  final double confidence;
  final bool outerRimOnly;
  double distance(BoardPoint p) => (a * p.x + b * p.y + c).abs();
}

class FusedHit {
  const FusedHit(
    this.point,
    this.residual,
    this.views, {
    this.forcedDecision = false,
  });
  final BoardPoint point;
  final double residual;
  final int views;
  final bool forcedDecision;
  bool get needsReview =>
      forcedDecision ||
      views < 3 ||
      residual > 3 ||
      BoardGeometry.nearWire(point);
}

/// Least squares intersection of camera dart axes on the calibrated board plane.
FusedHit? fuseAxes(List<DartAxis> axes) {
  final result = _fuseAxes(axes);
  if (result != null || axes.length != 3) return result;
  final ranked = axes.toList()
    ..sort((a, b) => b.confidence.compareTo(a.confidence));
  // Drop only an independently weak observation. Two lines alone cannot
  // identify which of three equally credible cameras is wrong.
  if (ranked[1].confidence >= .7 &&
      ranked[2].confidence < ranked[1].confidence * .5) {
    return _fuseAxes(ranked.take(2).toList());
  }
  return null;
}

FusedHit? decideAxes(List<DartAxis> axes) {
  final fit = _fuseAxes(axes, relaxed: true);
  if (fit == null) return null;
  return FusedHit(fit.point, fit.residual, fit.views, forcedDecision: true);
}

FusedHit? _fuseAxes(List<DartAxis> axes, {bool relaxed = false}) {
  if (axes.length < 2) return null;
  double aa = 0, ab = 0, bb = 0, ac = 0, bc = 0;
  for (final l in axes) {
    final weight = l.confidence * l.confidence;
    aa += weight * l.a * l.a;
    ab += weight * l.a * l.b;
    bb += weight * l.b * l.b;
    ac += weight * l.a * l.c;
    bc += weight * l.b * l.c;
  }
  final det = aa * bb - ab * ab;
  // Nearly parallel views amplify tiny pixel errors into large position errors.
  final minimumSeparation = relaxed
      ? (axes.length == 2 && axes.every((axis) => axis.confidence >= .7)
            ? .0025
            : .005)
      : .02;
  if (det / ((aa + bb) * (aa + bb)) < minimumSeparation) return null;
  final p = Point((ab * bc - bb * ac) / det, (ab * ac - aa * bc) / det);
  final residual = sqrt(
    axes.fold<double>(0, (sum, l) => sum + pow(l.distance(p), 2)) / axes.length,
  );
  if (!p.x.isFinite ||
      !p.y.isFinite ||
      p.magnitude > BoardGeometry.detectionRadius ||
      (!relaxed &&
          p.magnitude <= 170 &&
          axes.any((axis) => axis.outerRimOnly) &&
          axes.where((axis) => !axis.outerRimOnly).length < 2 &&
          !(axes.length == 2 &&
              axes.any((axis) => !axis.outerRimOnly) &&
              axes.every((axis) => axis.confidence >= .85))) ||
      (!relaxed && residual > 8)) {
    return null;
  }
  return FusedHit(
    p,
    residual,
    axes.length,
    forcedDecision: p.magnitude <= 170 && axes.any((axis) => axis.outerRimOnly),
  );
}
