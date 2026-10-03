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
  final root = 'test/fixtures/autoscoring/batch3/$name';
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
  test(
    'Uncertain decision still rejects weak, parallel and out-of-board axes',
    () {
      List<DartAxis> pair(double angle, double confidence, Point<double> tip) {
        return [
          DartAxis(tip, tip + const Point(100.0, 0.0), confidence: confidence),
          DartAxis(
            tip,
            tip + Point(100 * cos(angle), 100 * sin(angle)),
            confidence: confidence,
          ),
        ];
      }

      expect(decideAxes(pair(.115, .69, const Point(110, -90))), isNull);
      expect(decideAxes(pair(.03, .95, const Point(110, -90))), isNull);
      expect(decideAxes(pair(.115, .95, const Point(250, 0))), isNull);
    },
  );
  test('Case 63 gives a bounded, uncertain 4 after the decision timeout', () {
    final d = load('autoscore_korrektur_63');
    expect(fuseAxes(d.axes), isNull);
    final hit = decideAxes(d.axes)!;
    expect(hit.needsReview, isTrue);
    expect(hit.forcedDecision, isTrue);
    expect(BoardGeometry.score(hit.point).label, '4');
    expect(
      hit.point.distanceTo(const Point(110.57142857142856, -90.42857142857143)),
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
    for (var i = 0; i < 8; i++) {
      c.processFrames(d.current);
    }
    expect(counted.length, 1);
    expect(counted.single.label, '4');
  });
  test(
    'Empty removal with changed third-camera texture clears after six observations',
    () {
      final d = load('autoscore_herausziehen_2');
      final r = AutomaticVisitReset();
      for (var i = 0; i < 5; i++) {
        expect(
          r.observe(
            empty: d.empty,
            occupied: d.before,
            current: d.current,
            stable: true,
            darts: 3,
            calibrations: d.calibrations,
          ),
          VisitResetState.waitingForEmpty,
        );
      }
      expect(
        r.observe(
          empty: d.empty,
          occupied: d.before,
          current: d.current,
          stable: true,
          darts: 3,
          calibrations: d.calibrations,
        ),
        VisitResetState.cleared,
      );
    },
  );
  test('A genuinely occupied third view still vetoes removal', () {
    final d = load('autoscore_herausziehen_2');
    final r = AutomaticVisitReset();
    for (var i = 0; i < 10; i++) {
      expect(
        r.observe(
          empty: d.empty,
          occupied: d.before,
          current: [d.before[0], d.current[1], d.current[2]],
          stable: true,
          darts: 3,
          calibrations: d.calibrations,
        ),
        VisitResetState.waitingForEmpty,
      );
    }
  });
  test('Case 75 records the remaining inaccurate shaft fit', () {
    final d = load('autoscore_korrektur_75');
    final hit = fuseAxes(d.axes)!;
    expect(BoardGeometry.score(hit.point).label, '9');
    expect(d.report['corrected'], '12');
    expect(hit.needsReview, isTrue);
  });
  test(
    'Case 9_2 cannot locate a new dart from its already advanced reference',
    () {
      final d = load('autoscore_korrektur_9_2');
      expect(d.report['corrected'], 'MISS');
      expect(d.axes, isEmpty);
    },
  );
}
