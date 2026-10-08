import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_tournament_manager/features/autoscoring/domain/frame_detector.dart';
import 'package:dart_tournament_manager/features/autoscoring/domain/board_geometry.dart';
import 'package:dart_tournament_manager/features/autoscoring/domain/lens_distortion.dart';
import 'package:dart_tournament_manager/features/autoscoring/domain/dart_tip_detection.dart';

void main() {
  test('Probe endpoints with occupied and empty references', () {
    final rows = <Object?>[];
    for (final id in [102, 134]) {
      final root = 'build/autoscore_analysis/boundaries_102_134/case_$id';
      final report =
          jsonDecode(File('$root/bericht.json').readAsStringSync()) as Map;
      final decisions = report['hit']['decisionFrames'] as List;
      for (var n = 0; n < decisions.length; n++) {
        final d = decisions[n] as Map;
        for (var i = 0; i < 3; i++) {
          final meta = report['cameras'][i] as Map;
          final calibration = BoardCalibration([
            for (final p in meta['calibration'])
              Point((p['x'] as num).toDouble(), (p['y'] as num).toDouble()),
          ], lens: LensDistortion.fromJson(meta['lens'] as Map));
          GrayFrame load(String name) {
            final f = decodeCameraFrame(
              File(
                '$root/kamera_${i + 1}_${name}_detail.png',
              ).readAsBytesSync(),
            );
            return f.detail ?? f;
          }

          final axis = d['axes'][i] as Map;
          final aa = (axis['a'] as num).toDouble(),
              bb = (axis['b'] as num).toDouble(),
              cc = (axis['c'] as num).toDouble();
          final origin = Point(-aa * cc, -bb * cc);
          final a = DartAxis(
            origin,
            origin + Point(-bb, aa) * 100,
            confidence: (axis['confidence'] as num).toDouble(),
          );
          final point = Point(
            (d['xMillimetres'] as num).toDouble(),
            (d['yMillimetres'] as num).toDouble(),
          );
          for (final ref in ['letzter_vorher', 'leer']) {
            for (final threshold in [24, 18, 12]) {
              final index = (meta['frameTimestampsMicroseconds'] as List)
                  .indexOf(d['captureTimestampsMicroseconds'][i]);
              final tip = detectDartTip(
                load(ref),
                load('sequenz_${index + 1}'),
                calibration,
                a,
                point,
                differenceThreshold: threshold,
              );
              rows.add({
                'case': id,
                'frame': n,
                'camera': i + 1,
                'reference': ref,
                'threshold': threshold,
                'tip': tip == null ? null : [tip.board.x, tip.board.y],
              });
            }
          }
        }
      }
    }
    File(
      'build/autoscore_analysis/boundaries_102_134/endpoint_probe.json',
    ).writeAsStringSync(jsonEncode(rows));
  });
}
