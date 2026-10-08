import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_tournament_manager/features/autoscoring/domain/board_geometry.dart';
import 'package:dart_tournament_manager/features/autoscoring/domain/lens_distortion.dart';
import 'package:dart_tournament_manager/features/autoscoring/domain/frame_detector.dart';
import 'package:dart_tournament_manager/features/autoscoring/domain/local_segment_boundary.dart';

void main() {
  test('Probe local wire measurements without correction feedback', () {
    final rows = [];
    for (final id in ['27', '89']) {
      final root = 'build/autoscore_analysis/new_27_89/case_$id';
      final report = jsonDecode(File('$root/bericht.json').readAsStringSync());
      final hit = report['hit'];
      final point = Point(
        (hit['xMillimetres'] as num).toDouble(),
        (hit['yMillimetres'] as num).toDouble(),
      );
      for (var i = 0; i < 3; i++) {
        final meta = report['cameras'][i];
        final calibration = BoardCalibration([
          for (final p in meta['calibration'])
            Point((p['x'] as num).toDouble(), (p['y'] as num).toDouble()),
        ], lens: LensDistortion.fromJson(meta['lens']));
        final low = decodeCameraFrame(
          File('$root/kamera_${i + 1}_leer.png').readAsBytesSync(),
        );
        final high = decodeCameraFrame(
          File('$root/kamera_${i + 1}_leer_detail.png').readAsBytesSync(),
        );
        final empty = GrayFrame(
          low.width,
          low.height,
          low.pixels,
          detail: high.detail ?? high,
        );
        rows.add({
          'case': id,
          'camera': i + 1,
          'boundary': measureLocalSegmentBoundary(
            empty,
            calibration,
            point,
          )?.toJson(),
        });
      }
    }
    File(
      'build/autoscore_analysis/local_boundary_probe.json',
    ).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(rows));
  });
}
