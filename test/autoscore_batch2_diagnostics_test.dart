import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_tournament_manager/features/autoscoring/domain/board_geometry.dart';
import 'package:dart_tournament_manager/features/autoscoring/domain/frame_detector.dart';
import 'package:dart_tournament_manager/features/autoscoring/domain/automatic_visit_reset.dart';
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
  final root = 'test/fixtures/autoscoring/batch2/$name';
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
    final a = frame('vorher'), b = frame('treffer');
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
  for (final id in [8, 1, 76, 73, 61]) {
    test('Recorded missing throw $id recovers the corrected 20', () {
      final data = load('autoscore_korrektur_$id');
      expect(data.axes.length, 2);
      expect(data.axes.every((a) => a.confidence >= .85), isTrue);
      final hit = fuseAxes(data.axes)!;
      expect(BoardGeometry.score(hit.point).label, data.report['corrected']);
      expect(hit.needsReview, isTrue);
      final target = data.report['correctionPosition'];
      expect(
        hit.point.distanceTo(
          Point(
            (target['xMillimetres'] as num).toDouble(),
            (target['yMillimetres'] as num).toDouble(),
          ),
        ),
        lessThan(id == 8 ? 8 : 3),
      );
      final counted = <DartThrowResult>[];
      final c = createController(counted);
      addTearDown(c.dispose);
      for (var i = 0; i < 3; i++) {
        c.cameras[i]
          ..calibration = data.calibrations[i]
          ..reference = data.before[i]
          ..emptyReference = data.empty[i]
          ..previous = data.current[i]
          ..stable = 2;
      }
      c.processFrames(data.current);
      expect(counted, isEmpty);
      c.processFrames(data.current);
      expect(counted.single.label, '20');
      c.processFrames(data.current);
      expect(counted.length, 1);
    });
  }
  test('Recorded empty board releases residuals after six quiet captures', () {
    final data = load('autoscore_herausziehen');
    final reset = AutomaticVisitReset();
    for (var i = 0; i < 5; i++) {
      expect(
        reset.observe(
          empty: data.empty,
          occupied: data.before,
          current: data.current,
          stable: true,
          darts: 3,
          calibrations: data.calibrations,
        ),
        VisitResetState.waitingForEmpty,
      );
    }
    expect(reset.cameraMetrics.first['residualRecovery'], isTrue);
    expect(
      reset.observe(
        empty: data.empty,
        occupied: data.before,
        current: data.current,
        stable: true,
        darts: 3,
        calibrations: data.calibrations,
      ),
      VisitResetState.cleared,
    );
    final counted = <DartThrowResult>[];
    final c = createController(counted);
    addTearDown(c.dispose);
    var cleared = 0;
    c.onAutomaticVisitCleared = () => cleared++;
    for (var i = 0; i < 3; i++) {
      c.cameras[i]
        ..calibration = data.calibrations[i]
        ..reference = data.before[i]
        ..emptyReference = data.empty[i]
        ..previous = data.current[i]
        ..stable = 2;
      c.throws.add(BoardGeometry.score(const Point(0, -120)));
    }
    for (var i = 0; i < 8; i++) {
      c.processFrames(data.current);
    }
    expect(cleared, 1);
    expect(c.throws, isEmpty);
    expect(c.pending, isNull);
    expect(c.waitingForEmpty, isFalse);
    expect(c.running, isTrue);
    expect(counted, isEmpty);
  });
  test('Two empty cameras cannot clear a genuinely occupied third camera', () {
    final data = load('autoscore_herausziehen');
    final reset = AutomaticVisitReset();
    for (var i = 0; i < 10; i++) {
      expect(
        reset.observe(
          empty: data.empty,
          occupied: data.before,
          current: [data.before[0], data.current[1], data.current[2]],
          stable: true,
          darts: 3,
          calibrations: data.calibrations,
        ),
        VisitResetState.waitingForEmpty,
      );
    }
  });
  test('Rim-supported pairs need two strong axes and an inner observation', () {
    DartAxis rim() => DartAxis(
      const Point(-40, -120),
      const Point(40, -120),
      confidence: .95,
      outerRimOnly: true,
    );
    DartAxis inner(double quality) =>
        DartAxis(const Point(0, -170), const Point(0, 0), confidence: quality);
    expect(fuseAxes([rim(), inner(.84)]), isNull);
    expect(fuseAxes([rim(), inner(.95)])!.needsReview, isTrue);
    expect(
      fuseAxes([
        rim(),
        DartAxis(
          const Point(0, -170),
          const Point(0, 0),
          confidence: .95,
          outerRimOnly: true,
        ),
      ]),
      isNull,
    );
  });
}
