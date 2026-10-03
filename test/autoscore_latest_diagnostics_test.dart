import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_tournament_manager/features/autoscoring/domain/board_geometry.dart';
import 'package:dart_tournament_manager/features/autoscoring/domain/frame_detector.dart';
import 'package:dart_tournament_manager/features/scorer/domain/x01/x01_models.dart';
import 'autoscoring_automatic_counting_test.dart' show createController;

({
  List<BoardCalibration> calibrations,
  List<GrayFrame> before,
  List<GrayFrame> current,
  List<DartAxis> axes,
})
replay(int id, String reference) {
  final root = 'test/fixtures/autoscoring/corrections/case_$id';
  final report = jsonDecode(File('$root/bericht.json').readAsStringSync());
  final calibrations = <BoardCalibration>[],
      before = <GrayFrame>[],
      current = <GrayFrame>[],
      axes = <DartAxis>[];
  for (var i = 0; i < 3; i++) {
    final cal = BoardCalibration([
      for (final p in report['cameras'][i]['calibration'])
        Point((p['x'] as num).toDouble(), (p['y'] as num).toDouble()),
    ]);
    final a = decodeCameraFrame(
      File('$root/kamera_${i + 1}_$reference.png').readAsBytesSync(),
    );
    final b = decodeCameraFrame(
      File('$root/kamera_${i + 1}_treffer.png').readAsBytesSync(),
    );
    calibrations.add(cal);
    before.add(a);
    current.add(b);
    final axis = const FrameDetector().axis(a, b, cal);
    if (axis != null) axes.add(axis);
  }
  return (
    calibrations: calibrations,
    before: before,
    current: current,
    axes: axes,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('Case 3 uses an additional rim-supported view to recover 20, not 1', () {
    final data = replay(3, 'vorher');
    expect(data.axes.length, 3);
    expect(data.axes.first.outerRimOnly, isTrue);
    final pair = fuseAxes(data.axes.skip(1).toList())!;
    expect(BoardGeometry.score(pair.point).label, '1');
    // A rim-only pair still cannot authorize a score inside the scoring board.
    expect(fuseAxes(data.axes.take(2).toList()), isNull);
    final hit = fuseAxes(data.axes)!;
    expect(BoardGeometry.score(hit.point).label, '20');
    expect(hit.views, 3);
    expect(hit.needsReview, isTrue);
    expect(
      hit.point.distanceTo(
        const Point(16.285714285714313, -150.64285714285714),
      ),
      lessThan(6),
    );
  });
  test(
    'Case 3 waits for its visible third view before committing one score',
    () {
      final data = replay(3, 'vorher');
      final counted = <DartThrowResult>[];
      final c = createController(counted);
      addTearDown(c.dispose);
      for (var i = 0; i < 3; i++) {
        c.cameras[i]
          ..calibration = data.calibrations[i]
          ..reference = data.before[i]
          ..emptyReference = data.before[i]
          ..previous = data.current[i]
          ..stable = i == 0 ? 0 : 2;
      }
      c.processFrames(data.current);
      expect(counted, isEmpty);
      c.processFrames(data.current);
      expect(counted.single.label, '20');
      expect(c.lastHit!.views, 3);
      c.processFrames(data.current);
      expect(counted.length, 1);
    },
  );
  for (final id in [38, 51, 91]) {
    test('Case $id current reference has no recoverable new impact', () {
      final data = replay(id, 'vorher');
      expect(data.axes, isEmpty);
      expect(fuseAxes(data.axes), isNull);
    });
  }
  test('Case 91 retains the original 20 in the older counted reference', () {
    final hit = fuseAxes(replay(91, 'letzter_vorher').axes)!;
    expect(BoardGeometry.score(hit.point).label, '20');
  });
  test('Cases 38 and 51 remain unresolved instead of inventing a score', () {
    expect(replay(38, 'letzter_vorher').axes.length, 1);
    expect(fuseAxes(replay(38, 'letzter_vorher').axes), isNull);
    expect(replay(51, 'letzter_vorher').axes.length, 2);
    expect(fuseAxes(replay(51, 'letzter_vorher').axes), isNull);
  });
}
