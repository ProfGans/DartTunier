import 'dart:math';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'board_geometry.dart';
import 'lens_distortion.dart';

class CalibrationObservation {
  const CalibrationObservation(this.image, this.board, this.sector);
  final BoardPoint image, board;
  final int sector;
}

class DenseCalibrationResult {
  const DenseCalibrationResult(this.calibration, this.metrics);
  final BoardCalibration calibration;
  final Map<String, Object?> metrics;
}

/// Overdetermined fit. Training and validation use different ring sectors.
DenseCalibrationResult fitDenseCalibration(
  BoardCalibration initial,
  List<CalibrationObservation> observations, {
  double aspectRatio = 1,
}) {
  double error(BoardCalibration c, List<CalibrationObservation> samples) =>
      sqrt(
        samples.fold<double>(
              0,
              (s, p) => s + pow(c.project(p.image).distanceTo(p.board), 2),
            ) /
            samples.length,
      );
  if (observations.length < 28 ||
      observations.map((o) => o.sector).toSet().length < 16) {
    return DenseCalibrationResult(initial, {
      'observations': observations.length,
      'applied': false,
      'reason': 'Zu wenige unabhängige Ringpunkte',
    });
  }
  final training = observations.where((o) => o.sector.isEven).toList();
  final validation = observations.where((o) => o.sector.isOdd).toList();
  if (training.length < 12 || validation.length < 12) {
    return DenseCalibrationResult(initial, {
      'observations': observations.length,
      'applied': false,
      'reason': 'Ringpunkte ungleich verteilt',
    });
  }
  final baseline = error(initial, validation);
  var best = initial, bestError = baseline;
  for (var step = -20; step <= 20; step++) {
    final range = min(1.0, aspectRatio * aspectRatio);
    if (step * .02 < -.2 * range || step * .02 > .4 * range) continue;
    final lens = LensDistortion(k1: step * .02, aspectRatio: aspectRatio);
    try {
      final candidate = _fit(training, lens);
      final e = error(candidate, validation);
      if (e < bestError) {
        best = candidate;
        bestError = e;
      }
    } on ArgumentError {
      continue;
    }
  }
  var applied = baseline - bestError >= .25 && bestError <= baseline * .8;
  var finalError = bestError;
  if (applied) {
    best = _fit(observations, best.lens);
    finalError = error(best, validation);
    // Refitting all observations must preserve the held-out improvement.
    if (!finalError.isFinite ||
        finalError > baseline * .8 ||
        baseline - finalError < .25) {
      applied = false;
    }
    // Ring texture cannot justify a large change of the whole board geometry.
    for (var angle = 0.0; angle < 2 * pi; angle += pi / 10) {
      for (final radius in [50.0, 103.0, 166.0, 220.0]) {
        final p = Point(sin(angle) * radius, -cos(angle) * radius);
        if (best.project(initial.unproject(p)).distanceTo(p) > 6) {
          applied = false;
        }
      }
    }
  }
  return DenseCalibrationResult(applied ? best : initial, {
    'observations': observations.length,
    'trainingObservationCount': training.length,
    'validationObservationCount': validation.length,
    'validationSectors': 'odd sectors; even sectors used for model selection',
    'principalPointAssumption': 'image centre',
    'validationRmsBeforeMillimetres': baseline,
    'validationRmsAfterMillimetres': bestError,
    'refittedRmsAfterMillimetres': finalError,
    'applied': applied,
    'lensK1': applied ? best.lens.k1 : initial.lens.k1,
  });
}

DenseCalibrationResult refineDenseBoard(
  Uint8List bytes,
  BoardCalibration initial,
) {
  final image = img.decodeImage(bytes);
  if (image == null) return DenseCalibrationResult(initial, {'applied': false});
  final observations = <CalibrationObservation>[];
  bool coloured(BoardPoint p) {
    final x = (p.x * (image.width - 1)).round(),
        y = (p.y * (image.height - 1)).round();
    if (x < 0 || y < 0 || x >= image.width || y >= image.height) return false;
    final v = image.getPixel(x, y);
    return (v.r > 30 && v.r > v.g * 1.3 && v.r > v.b * 1.2) ||
        (v.g > 30 && v.g > v.r * 1.2 && v.g > v.b * 1.1);
  }

  for (var sector = 0; sector < 20; sector++) {
    final angle = sector * pi / 10;
    for (final centre in [103.0, 166.0]) {
      final runs = <List<double>>[];
      var run = <double>[];
      for (var r = centre - 12; r <= centre + 12; r += .25) {
        if (coloured(
          initial.unproject(Point(sin(angle) * r, -cos(angle) * r)),
        )) {
          run.add(r);
        } else if (run.isNotEmpty) {
          runs.add(run);
          run = [];
        }
      }
      if (run.isNotEmpty) runs.add(run);
      final valid = runs.where((r) => r.length >= 12 && r.length <= 56).toList()
        ..sort(
          (a, b) => ((a.first + a.last) / 2 - centre).abs().compareTo(
            ((b.first + b.last) / 2 - centre).abs(),
          ),
        );
      if (valid.isEmpty) continue;
      final observedRadius = (valid.first.first + valid.first.last) / 2;
      observations.add(
        CalibrationObservation(
          initial.unproject(
            Point(sin(angle) * observedRadius, -cos(angle) * observedRadius),
          ),
          Point(sin(angle) * centre, -cos(angle) * centre),
          sector,
        ),
      );
    }
  }
  return fitDenseCalibration(
    initial,
    observations,
    aspectRatio: image.width / image.height,
  );
}

BoardCalibration _fit(
  List<CalibrationObservation> observations,
  LensDistortion lens,
) {
  final normal = List.generate(8, (_) => List.filled(9, 0.0));
  for (final observation in observations) {
    final p = lens.undistort(observation.image),
        q = observation.board * (1 / 170);
    for (final row in [
      [p.x, p.y, 1.0, 0.0, 0.0, 0.0, -q.x * p.x, -q.x * p.y, q.x],
      [0.0, 0.0, 0.0, p.x, p.y, 1.0, -q.y * p.x, -q.y * p.y, q.y],
    ]) {
      for (var i = 0; i < 8; i++) {
        for (var j = 0; j < 9; j++) {
          normal[i][j] += row[i] * row[j];
        }
      }
    }
  }
  for (var col = 0; col < 8; col++) {
    var pivot = col;
    for (var row = col + 1; row < 8; row++) {
      if (normal[row][col].abs() > normal[pivot][col].abs()) pivot = row;
    }
    final swap = normal[col];
    normal[col] = normal[pivot];
    normal[pivot] = swap;
    final divisor = normal[col][col];
    if (divisor.abs() < 1e-10) throw ArgumentError('Ringfit nicht bestimmbar');
    for (var j = col; j < 9; j++) {
      normal[col][j] /= divisor;
    }
    for (var row = 0; row < 8; row++) {
      if (row == col) continue;
      final factor = normal[row][col];
      for (var j = col; j < 9; j++) {
        normal[row][j] -= factor * normal[col][j];
      }
    }
  }
  final h = [for (var i = 0; i < 8; i++) normal[i][8]];
  BoardPoint inverse(BoardPoint q) {
    final a = h[0] - q.x * h[6],
        b = h[1] - q.x * h[7],
        c = h[3] - q.y * h[6],
        d = h[4] - q.y * h[7],
        x = q.x - h[2],
        y = q.y - h[5],
        det = a * d - b * c;
    return lens.distort(Point((x * d - b * y) / det, (a * y - x * c) / det));
  }

  return BoardCalibration([
    for (final p in const [
      Point(0.0, -1.0),
      Point(1.0, 0.0),
      Point(0.0, 1.0),
      Point(-1.0, 0.0),
    ])
      inverse(p),
  ], lens: lens);
}
