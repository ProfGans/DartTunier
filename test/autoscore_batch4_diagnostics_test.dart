import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_tournament_manager/features/autoscoring/domain/board_geometry.dart';
import 'package:dart_tournament_manager/features/autoscoring/domain/frame_detector.dart';
import 'package:dart_tournament_manager/features/scorer/domain/x01/x01_models.dart';
import 'autoscoring_automatic_counting_test.dart' show createController;

({
  Map<String, dynamic> report,
  List<BoardCalibration> calibrations,
  List<GrayFrame> before,
  List<GrayFrame> empty,
  List<GrayFrame> current,
  List<DartAxis> axes,
})
load(String name) {
  final root = 'test/fixtures/autoscoring/batch4/$name';
  final report =
      jsonDecode(File('$root/bericht.json').readAsStringSync())
          as Map<String, dynamic>;
  final axes = <DartAxis>[],
      cals = <BoardCalibration>[],
      before = <GrayFrame>[],
      empty = <GrayFrame>[],
      current = <GrayFrame>[];
  for (var i = 0; i < 3; i++) {
    final cal = BoardCalibration([
      for (final p in report['cameras'][i]['calibration'])
        Point((p['x'] as num).toDouble(), (p['y'] as num).toDouble()),
    ]);
    GrayFrame frame(String suffix) => decodeCameraFrame(
      File('$root/kamera_${i + 1}_$suffix.png').readAsBytesSync(),
    );
    final a = frame('letzter_vorher'), b = frame('treffer');
    before.add(a);
    current.add(b);
    empty.add(frame('leer'));
    cals.add(cal);
    final axis = const FrameDetector().axis(a, b, cal);
    if (axis != null) axes.add(axis);
  }
  return (
    report: report,
    calibrations: cals,
    before: before,
    empty: empty,
    current: current,
    axes: axes,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('Recorded case 68 recovers 20 once from a strong proximal shaft', () {
    final d = load('autoscore_korrektur_68');
    expect(d.axes.length, 2);
    expect(d.axes.every((a) => a.confidence >= .8), isTrue);
    expect(fuseAxes(d.axes), isNull);
    final hit = decideAxes(d.axes)!;
    expect(BoardGeometry.score(hit.point).label, '20');
    expect(hit.needsReview, isTrue);
    expect(
      hit.point.distanceTo(const Point(6.857142857142833, -91.28571428571428)),
      lessThan(6),
    );
    final counted = <DartThrowResult>[];
    final c = createController(counted);
    addTearDown(c.dispose);
    for (var i = 0; i < 3; i++) {
      c.cameras[i]
        ..calibration = d.calibrations[i]
        ..reference = d.before[i]
        ..emptyReference = d.empty[i]
        ..previous = d.current[i]
        ..stable = 2;
    }
    for (var k = 0; k < 8; k++) {
      c.processFrames(d.current);
    }
    expect(counted.length, 1);
    expect(counted.single.label, '20');
  });
  for (final values in [(143, 'T5', 'T20'), (24, '5', 'T5')]) {
    test(
      'Known position limitation ${values.$1} stays reproducible and marked uncertain',
      () {
        final d = load('autoscore_korrektur_${values.$1}');
        final h = fuseAxes(d.axes)!;
        expect(BoardGeometry.score(h.point).label, values.$2);
        expect(d.report['corrected'], values.$3);
        expect(h.needsReview, isTrue);
      },
    );
  }
}
