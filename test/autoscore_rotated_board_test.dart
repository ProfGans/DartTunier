import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_tournament_manager/features/autoscoring/domain/board_geometry.dart';
import 'package:dart_tournament_manager/features/autoscoring/domain/reference_board_calibration.dart';
import 'package:dart_tournament_manager/features/autoscoring/domain/frame_detector.dart';

void main() {
  test(
    'Actual rotated-board capture scores T20 with fresh Windows calibration',
    () {
      const root = 'test/fixtures/autoscoring/rotated_board';
      final report = jsonDecode(
        File('$root/ocr_verified.json').readAsStringSync(),
      );
      final axes = <DartAxis>[];
      for (var i = 1; i <= 3; i++) {
        final calibration = BoardCalibration([
          for (final p in report['cameras'][i - 1]['calibration'])
            Point((p['x'] as num).toDouble(), (p['y'] as num).toDouble()),
        ]);
        final axis = const FrameDetector().axis(
          decodeCameraFrame(File('$root/before_$i.png').readAsBytesSync()),
          decodeCameraFrame(File('$root/camera_$i.png').readAsBytesSync()),
          calibration,
        );
        expect(axis, isNotNull, reason: 'Camera $i');
        axes.add(axis!);
      }
      final hit = fuseAxes(axes);
      expect(hit, isNotNull);
      expect(BoardGeometry.score(hit!.point).label, 'T20');
    },
  );
  test('Rotated board transfers freshly OCR-read orientation to camera 1', () {
    const root = 'test/fixtures/autoscoring/rotated_board';
    final report = jsonDecode(File('$root/ocr_report.json').readAsStringSync());
    for (final reference in [2, 3]) {
      final calibration = BoardCalibration([
        for (final p in report['cameras'][reference - 1]['calibration'])
          Point((p['x'] as num).toDouble(), (p['y'] as num).toDouble()),
      ]);
      final result = calibrateFromReference(
        ReferenceCalibrationInput(
          File('$root/camera_1.png').readAsBytesSync(),
          File('$root/camera_$reference.png').readAsBytesSync(),
          calibration,
        ),
      );
      // Numeral 20 is visibly near x=.37, y=.215 in camera 1.
      final p = result.calibration.project(const Point(.37, .215));
      expect(
        atan2(p.x, -p.y).abs(),
        lessThan(pi / 20),
        reason: 'Reference $reference',
      );
    }
  });
}
