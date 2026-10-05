import 'dart:math';
import 'board_geometry.dart';
import 'dart_tip_detection.dart';

class Point3 {
  const Point3(this.x, this.y, this.z);
  final double x, y, z;
  Point3 operator +(Point3 b) => Point3(x + b.x, y + b.y, z + b.z);
  Point3 operator -(Point3 b) => Point3(x - b.x, y - b.y, z - b.z);
  Point3 operator *(double s) => Point3(x * s, y * s, z * s);
  double dot(Point3 b) => x * b.x + y * b.y + z * b.z;
  double get length => sqrt(dot(this));
  Point3 get unit => this * (1 / length);
  Point3 cross(Point3 b) =>
      Point3(y * b.z - z * b.y, z * b.x - x * b.z, x * b.y - y * b.x);
}

class CameraBoardPose {
  const CameraBoardPose(
    this.centre,
    this.r1,
    this.r2,
    this.r3,
    this.focal,
    this.aspect,
  );
  final Point3 centre, r1, r2, r3;
  final double focal, aspect;
  Point3 ray(BoardPoint image) {
    final c = Point3(
      (image.x - .5) / focal,
      (image.y - .5) / aspect / focal,
      1,
    );
    return Point3(r1.dot(c), r2.dot(c), r3.dot(c)).unit;
  }
}

/// Restricted intrinsic estimate from a metric plane: square pixels and centred
/// principal point are assumptions. Reject views whose independent constraints
/// disagree; this is not a replacement for a calibration rig for arbitrary lenses.
CameraBoardPose? estimateBoardPose(
  BoardCalibration calibration, {
  double? aspectRatio,
}) {
  final aspect = aspectRatio ?? calibration.lens.aspectRatio;
  final rows = <List<double>>[];
  const board = [
    Point(0.0, -1.0),
    Point(1.0, 0.0),
    Point(0.0, 1.0),
    Point(-1.0, 0.0),
  ];
  for (var i = 0; i < 4; i++) {
    final p = board[i], q = calibration.lens.undistort(calibration.points[i]);
    rows.add([p.x, p.y, 1, 0, 0, 0, -q.x * p.x, -q.x * p.y, q.x]);
    rows.add([0, 0, 0, p.x, p.y, 1, -q.y * p.x, -q.y * p.y, q.y]);
  }
  final h = _solve(rows);
  if (h == null) return null;
  final a = Point3(h[0] - .5 * h[6], (h[3] - .5 * h[6]) / aspect, h[6]);
  final b = Point3(h[1] - .5 * h[7], (h[4] - .5 * h[7]) / aspect, h[7]);
  final d1 = a.z * b.z, d2 = a.z * a.z - b.z * b.z;
  if (d1.abs() < 1e-8 || d2.abs() < 1e-8) return null;
  final f1 = -(a.x * b.x + a.y * b.y) / d1;
  final f2 = -(a.x * a.x + a.y * a.y - b.x * b.x - b.y * b.y) / d2;
  if (f1 <= 0 || f2 <= 0 || (f1 - f2).abs() / max(f1, f2) > .1) return null;
  final f = sqrt((f1 + f2) / 2);
  if (f < .3 || f > 3) return null;
  final u = Point3(a.x / f, a.y / f, a.z), v = Point3(b.x / f, b.y / f, b.z);
  final r1 = u.unit, r2 = (v - r1 * v.dot(r1)).unit, r3 = r1.cross(r2).unit;
  final scale = 340 / (u.length + v.length);
  final t = Point3((h[2] - .5) / f, (h[5] - .5) / aspect / f, 1) * scale;
  final centre = Point3(-r1.dot(t), -r2.dot(t), -r3.dot(t));
  if (centre.length < 100 || centre.length > 3000) return null;
  return CameraBoardPose(centre, r1, r2, r3, f, aspect);
}

class SpatialBoardContact {
  const SpatialBoardContact(
    this.point,
    this.residual,
    this.views,
    this.robinHood,
  );
  final Point3 point;
  final double residual;
  final int views;
  final bool robinHood;
  Map<String, Object?> toJson() => {
    'xMillimetres': point.x,
    'yMillimetres': point.y,
    'heightMillimetres': point.z.abs(),
    'rayResidualMillimetres': residual,
    'views': views,
    'robinHood': robinHood,
    'intrinsicsAssumption': 'centredSquarePixels',
  };
}

SpatialBoardContact? locateSpatialContact(
  List<CameraBoardPose?> poses,
  List<DartTipObservation?> tips,
  List<BoardPoint> existingHits,
) {
  final normal = List.generate(3, (_) => List.filled(4, 0.0));
  final rays = <(Point3, Point3)>[];
  for (var i = 0; i < poses.length; i++) {
    final pose = poses[i], tip = tips[i];
    if (pose == null || tip == null || tip.confidence < .85) continue;
    final ray = pose.ray(tip.image), c = pose.centre;
    final d = [ray.x, ray.y, ray.z], p = [c.x, c.y, c.z];
    rays.add((c, ray));
    for (var r = 0; r < 3; r++) {
      for (var s = 0; s < 3; s++) {
        final value = (r == s ? 1.0 : 0.0) - d[r] * d[s];
        normal[r][s] += value;
        normal[r][3] += value * p[s];
      }
    }
  }
  if (rays.length < 3) return null;
  final solved = _solve(normal);
  if (solved == null) return null;
  final point = Point3(solved[0], solved[1], solved[2]);
  final residual = sqrt(
    rays.fold<double>(0, (s, ray) {
          final delta = point - ray.$1;
          return s + pow((delta - ray.$2 * delta.dot(ray.$2)).length, 2);
        }) /
        rays.length,
  );
  if (!residual.isFinite || residual > 3 || point.length > 500) return null;
  if (rays.any((ray) => (point - ray.$1).dot(ray.$2) <= 0)) return null;
  final xy = Point(point.x, point.y);
  final robin =
      rays.every((ray) => point.z * ray.$1.z > 0) &&
      point.z.abs() >= 20 &&
      point.z.abs() <= 150 &&
      existingHits.any((p) => p.distanceTo(xy) <= 15);
  return SpatialBoardContact(point, residual, rays.length, robin);
}

List<double>? _solve(List<List<double>> source) {
  final rows = [for (final row in source) List<double>.of(row)];
  final size = rows.length;
  for (var col = 0; col < size; col++) {
    var pivot = col;
    for (var row = col + 1; row < size; row++) {
      if (rows[row][col].abs() > rows[pivot][col].abs()) pivot = row;
    }
    final swap = rows[col];
    rows[col] = rows[pivot];
    rows[pivot] = swap;
    if (rows[col][col].abs() < 1e-9) return null;
    final divisor = rows[col][col];
    for (var j = col; j <= size; j++) {
      rows[col][j] /= divisor;
    }
    for (var row = 0; row < size; row++) {
      if (row == col) continue;
      final factor = rows[row][col];
      for (var j = col; j <= size; j++) {
        rows[row][j] -= factor * rows[col][j];
      }
    }
  }
  return [for (var i = 0; i < size; i++) rows[i][size]];
}
