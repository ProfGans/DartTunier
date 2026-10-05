import 'dart:math';
import 'board_geometry.dart';

/// Ground truth exists only when a correction point was explicitly placed.
class PositionCorrectionSample {
  const PositionCorrectionSample(this.expected, this.detected, this.cameraAxes);
  final BoardPoint expected;
  final BoardPoint? detected;
  final List<Map<String, Object?>?> cameraAxes;
}

PositionCorrectionSample? correctionSampleFromReport(
  Map<dynamic, dynamic> report,
) {
  final position = report['correctionPosition'];
  if (position is! Map) return null;
  BoardPoint? point(Map values) {
    final x = values['xMillimetres'], y = values['yMillimetres'];
    if (x is! num || y is! num || !x.isFinite || !y.isFinite) return null;
    final p = BoardPoint(x.toDouble(), y.toDouble());
    return p.magnitude <= BoardGeometry.detectionRadius ? p : null;
  }

  final expected = point(position);
  if (expected == null) return null;
  final hit = report['hit'];
  return PositionCorrectionSample(expected, hit is Map ? point(hit) : null, [
    for (final camera in report['cameras'] as List? ?? [])
      camera['axis'] is Map
          ? (camera['axis'] as Map).cast<String, Object?>()
          : null,
  ]);
}

Map<String, Object?> analysePositionCorrections(
  List<PositionCorrectionSample> samples,
) {
  final positioned = samples.where((s) => s.detected != null).toList();
  final errors = [for (final s in positioned) s.expected - s.detected!];
  Map<String, Object?> moments(List<double> values) {
    if (values.isEmpty) return {'count': 0};
    final mean = values.reduce((a, b) => a + b) / values.length;
    final spread = sqrt(
      values.fold<double>(0, (s, v) => s + pow(v - mean, 2)) / values.length,
    );
    return {
      'count': values.length,
      'meanMillimetres': mean,
      'spreadMillimetres': spread,
    };
  }

  return {
    'positionedCorrections': samples.length,
    'missingPositionCount': samples.where((s) => s.detected == null).length,
    'xError': moments(errors.map((p) => p.x).toList()),
    'yError': moments(errors.map((p) => p.y).toList()),
    'meanDistanceMillimetres': errors.isEmpty
        ? null
        : errors.fold<double>(0, (s, p) => s + p.magnitude) / errors.length,
    'cameras': [
      for (var i = 0; i < 3; i++)
        {
          'camera': i + 1,
          'signedAxisError': moments([
            for (final sample in samples)
              if (sample.cameraAxes.length > i && sample.cameraAxes[i] != null)
                (() {
                  final axis = sample.cameraAxes[i]!;
                  final a = (axis['a'] as num).toDouble(),
                      b = (axis['b'] as num).toDouble(),
                      c = (axis['c'] as num).toDouble();
                  // PCA direction may flip between frames; canonical orientation
                  // is essential before interpreting signed errors as a bias.
                  return (a * sample.expected.x + b * sample.expected.y + c) *
                      ((a.abs() < 1e-9 ? b : a) < 0 ? -1 : 1);
                })(),
          ]),
        },
    ],
    'automaticBiasCorrectionApplied': false,
  };
}
