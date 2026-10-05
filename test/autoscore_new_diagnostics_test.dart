import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_tournament_manager/features/autoscoring/domain/board_geometry.dart';
import 'package:dart_tournament_manager/features/autoscoring/domain/frame_detector.dart';
import 'package:dart_tournament_manager/features/scorer/domain/x01/x01_models.dart';
import 'autoscoring_automatic_counting_test.dart' show createController;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final id in [40, 43, 46, 59]) {
    test('Diagnostic $id preserves available and missing observations', () {
      final root = 'test/fixtures/autoscoring/corrections/case_$id';
      final report = jsonDecode(File('$root/bericht.json').readAsStringSync());
      final axes = <DartAxis>[];
      for (var i = 0; i < 3; i++) {
        final cal = BoardCalibration([
          for (final p in report['cameras'][i]['calibration'])
            Point((p['x'] as num).toDouble(), (p['y'] as num).toDouble()),
        ]);
        final before = decodeCameraFrame(
          File('$root/kamera_${i + 1}_vorher.png').readAsBytesSync(),
        );
        final current = decodeCameraFrame(
          File('$root/kamera_${i + 1}_treffer.png').readAsBytesSync(),
        );
        final axis = const FrameDetector().axis(before, current, cal);
        if (axis != null) axes.add(axis);
        if (id == 43 || id == 59) {
          // The supplied reference already contains the darts. These archives
          // cannot reproduce their original impact; never invent a hit for them.
          expect(
            const FrameDetector().changedFraction(before, current),
            lessThan(.0003),
          );
        }
      }
      final hit = fuseAxes(axes);
      if (id == 46) {
        expect(hit!.views, 3);
        expect(BoardGeometry.score(hit.point).label, '19');
        expect(
          BoardGeometry.score(fuseAxes(axes.skip(1).toList())!.point).label,
          '7',
        );
      } else if (id == 40) {
        // Two strong views now reconstruct a tentative hit. This archive has
        // no verified target score/point; do not treat it as proven accuracy.
        expect(hit, isNotNull);
        expect(hit!.views, 2);
        expect(hit.needsReview, isTrue);
        expect(axes.every((axis) => axis.confidence >= .85), isTrue);
      } else {
        expect(hit, isNull);
      }
    });
  }
  test('Near-wire pair waits for settling third camera before counting 19', () {
    const root = 'test/fixtures/autoscoring/corrections/case_46';
    final report = jsonDecode(File('$root/bericht.json').readAsStringSync());
    final counted = <DartThrowResult>[];
    final c = createController(counted);
    addTearDown(c.dispose);
    final frames = <GrayFrame>[];
    for (var i = 0; i < 3; i++) {
      final before = decodeCameraFrame(
        File('$root/kamera_${i + 1}_vorher.png').readAsBytesSync(),
      );
      frames.add(
        decodeCameraFrame(
          File('$root/kamera_${i + 1}_treffer.png').readAsBytesSync(),
        ),
      );
      c.cameras[i]
        ..calibration = BoardCalibration([
          for (final p in report['cameras'][i]['calibration'])
            Point((p['x'] as num).toDouble(), (p['y'] as num).toDouble()),
        ])
        ..reference = before
        ..emptyReference = before
        ..previous = frames[i]
        ..stable = i == 0 ? 0 : 2;
    }
    c.processFrames(frames);
    expect(counted, isEmpty);
    c.processFrames(frames);
    expect(counted, isEmpty);
    c.processFrames(frames);
    expect(counted.single.label, '19');
    expect(c.lastHit!.views, 3);
  });
}
