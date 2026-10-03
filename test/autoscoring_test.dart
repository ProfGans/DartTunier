import 'dart:math';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_tournament_manager/features/autoscoring/domain/board_geometry.dart';
import 'package:dart_tournament_manager/features/autoscoring/domain/frame_detector.dart';

void main() {
  test('A stuck dart on the black outer rim is detected and scores zero', () {
    final calibration = BoardCalibration(const [
      Point(.5, .2),
      Point(.8, .5),
      Point(.5, .8),
      Point(.2, .5),
    ]);
    final empty = GrayFrame(480, 480, Uint8List(480 * 480));
    GrayFrame shaft(Point<double> a, Point<double> b) {
      final pixels = Uint8List(480 * 480);
      for (var step = 0; step <= 800; step++) {
        final q = calibration.unproject(a + (b - a) * (step / 800));
        final x = (q.x * 479).round(), y = (q.y * 479).round();
        for (var dy = -1; dy <= 1; dy++) {
          for (var dx = -1; dx <= 1; dx++) {
            if (x + dx >= 0 && x + dx < 480 && y + dy >= 0 && y + dy < 480) {
              pixels[(y + dy) * 480 + x + dx] = 180;
            }
          }
        }
      }
      return GrayFrame(480, 480, pixels);
    }

    final first = shaft(const Point(-45, -215), const Point(45, -215));
    final second = shaft(const Point(0, -230), const Point(0, -180));
    final detector = FrameDetector();
    final a = detector.axis(empty, first, calibration);
    final b = detector.axis(empty, second, calibration);
    expect(a, isNotNull);
    expect(b, isNotNull);
    expect(detector.changeSamples(empty, first, calibration), isNotEmpty);
    final hit = fuseAxes([a!, b!])!;
    expect(hit.point.distanceTo(const Point(0, -215)), lessThan(2));
    expect(BoardGeometry.score(hit.point).scoredPoints, 0);
    expect(
      fuseAxes([
        DartAxis(const Point(-50, -245), const Point(50, -245)),
        DartAxis(const Point(0, -260), const Point(0, -180)),
      ]),
      isNull,
    );
  });

  test(
    'Decision fallback fixes one bounded position and marks it uncertain',
    () {
      final axes = [
        DartAxis(const Point(-100, -103), const Point(100, -103)),
        DartAxis(const Point(0, -170), const Point(0, 100)),
        DartAxis(const Point(-100, -70), const Point(100, -70)),
      ];
      expect(fuseAxes(axes), isNull);
      final hit = decideAxes(axes)!;
      expect(hit.needsReview, isTrue);
      expect(hit.forcedDecision, isTrue);
      expect(hit.point.distanceTo(decideAxes(axes)!.point), 0);
    },
  );
  test(
    'A independently weak conflicting third view cannot block two clear axes',
    () {
      final hit = fuseAxes([
        DartAxis(const Point(-100, -103), const Point(100, -103)),
        DartAxis(const Point(0, -170), const Point(0, 100)),
        DartAxis(const Point(-100, -10), const Point(100, -10), confidence: .2),
      ])!;
      expect(hit.views, 2);
      expect(hit.needsReview, isTrue);
      expect(BoardGeometry.score(hit.point).label, 'T20');
    },
  );
  final calibration = BoardCalibration(const [
    Point(.5, .1),
    Point(.9, .5),
    Point(.5, .9),
    Point(.1, .5),
  ]);
  test(
    'A short visible shaft at working resolution survives partial occlusion',
    () {
      final empty = GrayFrame(480, 480, Uint8List(480 * 480));
      final pixels = Uint8List(480 * 480);
      for (var x = 220; x < 240; x++) {
        pixels[200 * 480 + x] = 180;
      }
      final axis = const FrameDetector().axis(
        empty,
        GrayFrame(480, 480, pixels),
        calibration,
      );
      expect(axis, isNotNull);
      expect(
        axis!.distance(calibration.project(const Point(.48, 200 / 479))),
        lessThan(1),
      );
    },
  );
  test(
    'Low-quality camera axis does not drag two clear views into another ring',
    () {
      final hit = fuseAxes([
        DartAxis(const Point(-100, -103), const Point(100, -103)),
        DartAxis(const Point(0, -170), const Point(0, 100)),
        DartAxis(const Point(-50, -141), const Point(50, -41), confidence: .2),
      ])!;
      expect(hit.point.distanceTo(const Point(0, -103)), lessThan(1));
      expect(BoardGeometry.score(hit.point).label, 'T20');
      expect(hit.needsReview, isTrue);
    },
  );
  test(
    'Flight-like outliers do not move the shaft axis across the triple ring',
    () {
      final empty = GrayFrame(320, 320, Uint8List(320 * 320));
      final pixels = Uint8List(320 * 320);
      for (var y = 80; y <= 84; y++) {
        for (var x = 110; x < 210; x++) {
          pixels[y * 320 + x] = 180;
        }
      }
      for (var y = 58; y < 78; y++) {
        for (var x = 180; x < 195; x++) {
          pixels[y * 320 + x] = 180;
        }
      }
      final axis = const FrameDetector().axis(
        empty,
        GrayFrame(320, 320, pixels),
        calibration,
      )!;
      expect(
        axis.distance(calibration.project(const Point(.5, 82 / 319))),
        lessThan(1),
      );
      expect(axis.confidence, lessThan(1));
    },
  );
  test('Almost parallel axes cannot authorize a precise score', () {
    expect(
      fuseAxes([
        DartAxis(const Point(-100, -103), const Point(100, -103)),
        DartAxis(const Point(-100, -108), const Point(100, -98)),
      ]),
      isNull,
    );
  });
  test(
    'Overlay inverse and image line follow a perspective camera transform',
    () {
      final perspective = BoardCalibration(const [
        Point(.48, .18),
        Point(.85, .45),
        Point(.52, .88),
        Point(.16, .56),
      ]);
      for (final p in [
        const Point(0.0, 0.0),
        const Point(0.0, -103.0),
        const Point(90.0, 40.0),
      ]) {
        expect(
          perspective.project(perspective.unproject(p)).distanceTo(p),
          lessThan(1e-8),
        );
      }
      final axis = DartAxis(const Point(-60, -103), const Point(90, -103));
      final segment = perspective.imageAxis(axis);
      expect(segment.length, 2);
      for (final point in segment) {
        expect(axis.distance(perspective.project(point)), lessThan(1e-8));
        expect(point.x, inInclusiveRange(0, 1));
        expect(point.y, inInclusiveRange(0, 1));
      }
    },
  );
  test('Homography maps reference points and bull', () {
    expect(calibration.project(const Point(.5, .5)).magnitude, lessThan(1e-8));
    expect(calibration.project(const Point(.5, .1)).y, closeTo(-170, 1e-8));
    expect(
      () => BoardCalibration(const [
        Point(.1, .1),
        Point(.2, .2),
        Point(.3, .3),
        Point(.4, .4),
      ]),
      throwsArgumentError,
    );
    expect(
      () => BoardCalibration(const [
        Point(.5, .1),
        Point(.5, .9),
        Point(.9, .5),
        Point(.1, .5),
      ]),
      throwsArgumentError,
    );
  });
  test(
    'Scores all sectors and scoring rings with standard board orientation',
    () {
      const wheel = [
        20,
        1,
        18,
        4,
        13,
        6,
        10,
        15,
        2,
        17,
        3,
        19,
        7,
        16,
        8,
        11,
        14,
        9,
        12,
        5,
      ];
      for (var i = 0; i < 20; i++) {
        final angle = i * pi / 10;
        for (final pair in [(70.0, 1), (103.0, 3), (166.0, 2)]) {
          final result = BoardGeometry.score(
            Point(sin(angle) * pair.$1, -cos(angle) * pair.$1),
          );
          expect(result.scoredPoints, wheel[i] * pair.$2);
        }
      }
      expect(BoardGeometry.score(const Point(0, 0)).scoredPoints, 50);
      expect(BoardGeometry.score(const Point(10, 0)).scoredPoints, 25);
      expect(BoardGeometry.score(const Point(171, 0)).isMiss, isTrue);
      expect(BoardGeometry.nearWire(const Point(0, -103)), isFalse);
      expect(BoardGeometry.nearWire(const Point(0, -99)), isTrue);
    },
  );
  test(
    'Three axes intersect and parallel or inconsistent axes are rejected',
    () {
      final hit = fuseAxes([
        DartAxis(const Point(-100, -103), const Point(100, -103)),
        DartAxis(const Point(0, -170), const Point(0, 100)),
        DartAxis(const Point(-50, -153), const Point(50, -53)),
      ])!;
      expect(hit.point.distanceTo(const Point(0, -103)), lessThan(1e-8));
      expect(hit.needsReview, isFalse);
      expect(BoardGeometry.score(hit.point).label, 'T20');
      expect(
        fuseAxes([
          DartAxis(const Point(0, 0), const Point(0, 1)),
          DartAxis(const Point(1, 0), const Point(1, 1)),
        ]),
        isNull,
      );
      expect(
        fuseAxes([
          DartAxis(const Point(0, 0), const Point(100, 0)),
          DartAxis(const Point(0, 0), const Point(0, 100)),
          DartAxis(const Point(100, 100), const Point(101, 99)),
        ]),
        isNull,
      );
    },
  );
  test('Image differencing extracts shaft axis and rejects broad movement', () {
    final empty = GrayFrame(320, 320, Uint8List(320 * 320));
    final pixels = Uint8List(320 * 320);
    for (var y = 155; y < 160; y++) {
      for (var x = 100; x < 210; x++) {
        pixels[y * 320 + x] = 180;
      }
    }
    final current = GrayFrame(320, 320, pixels);
    const detector = FrameDetector();
    final axis = detector.axis(empty, current, calibration);
    expect(axis, isNotNull);
    expect(
      axis!.distance(calibration.project(const Point(.5, 157 / 319))),
      lessThan(1),
    );
    expect(detector.axis(empty, empty, calibration), isNull);
    expect(
      detector.axis(
        empty,
        GrayFrame(320, 320, Uint8List.fromList(List.filled(320 * 320, 180))),
        calibration,
      ),
      isNull,
    );
    expect(detector.changedFraction(current, current), 0);
    final noise = Uint8List(320 * 320);
    for (var x = 100; x < 210; x += 4) {
      noise[157 * 320 + x] = 180;
    }
    expect(
      detector.axis(empty, GrayFrame(320, 320, noise), calibration),
      isNull,
    );
  });
}
