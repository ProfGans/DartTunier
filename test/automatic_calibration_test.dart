import 'dart:math';
import 'dart:io';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dart_tournament_manager/features/autoscoring/data/calibration_reference_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:dart_tournament_manager/features/autoscoring/domain/automatic_board_calibration.dart';
import 'package:dart_tournament_manager/features/autoscoring/domain/board_geometry.dart';
import 'package:dart_tournament_manager/features/autoscoring/domain/ocr_board_numbers.dart';
import 'package:dart_tournament_manager/features/autoscoring/data/automatic_calibration_service.dart';
import 'package:dart_tournament_manager/features/autoscoring/domain/board_number_sheet.dart';
import 'package:dart_tournament_manager/features/autoscoring/domain/reference_board_calibration.dart';

img.Image boardImage(BoardOutline outline) {
  final picture = img.Image(width: 640, height: 480);
  img.fill(picture, color: img.ColorRgb8(30, 30, 30));
  for (final pixel in picture) {
    final q = outline.rectify(Point(pixel.x / 639, pixel.y / 479)),
        r = q.magnitude;
    if (r > 1) continue;
    final sector =
        ((atan2(q.x, -q.y) + 2 * pi + pi / 20) % (2 * pi) / (pi / 10)).floor();
    if (r < 6.35 / 170) {
      pixel.setRgb(190, 25, 30);
    } else if (r < 15.9 / 170) {
      pixel.setRgb(20, 135, 60);
    } else if (r > 162 / 170 || (r > 99 / 170 && r < 107 / 170)) {
      if (sector.isEven) {
        pixel.setRgb(190, 25, 30);
      } else {
        pixel.setRgb(20, 135, 60);
      }
    } else {
      final shade = sector.isEven ? 30 : 200;
      pixel.setRgb(shade, shade, shade);
    }
  }
  return picture;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'Stored wrong orientation never bypasses fresh numeral recognition',
    () async {
      final image = File(
        'test/fixtures/autoscoring/camera_1.png',
      ).readAsBytesSync();
      final outline = detectBoardOutline(image).outline;
      final wrong = BoardCalibration([
        for (var i = 0; i < 4; i++)
          outline.unrectify(Point(sin(i * pi / 2), -cos(i * pi / 2))),
      ]);
      SharedPreferences.setMockInitialValues({});
      await const CalibrationReferenceStorage().remember(image, wrong);
      const channel = MethodChannel('fresh_rotation_test');
      var calls = 0;
      const rotation = pi * 2 / 5;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls++;
            if (calls != 1) return [];
            final args = call.arguments as Map;
            final width = args['width'] as int, height = args['height'] as int;
            return [
              for (final pair in [(20, 0), (6, 5), (3, 10), (11, 15)])
                (() {
                  final angle = rotation + pair.$2 * pi / 10;
                  return {
                    'text': '${pair.$1}',
                    'x':
                        (sin(angle) * 1.18 / AutomaticCalibrationImage.extent +
                                1) /
                            2 *
                            (width - 1) -
                        5,
                    'y':
                        (-cos(angle) * 1.18 / AutomaticCalibrationImage.extent +
                                1) /
                            2 *
                            (height - 1) -
                        5,
                    'width': 10.0,
                    'height': 10.0,
                  };
                })(),
            ];
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
      final result = await const WindowsAutomaticCalibrationService(
        channel: channel,
      ).calibrate(image);
      expect(calls, 4);
      expect(result.numberCount, 4);
      final top = outline.rectify(result.calibration.points.first);
      expect(
        atan2(
          sin(atan2(top.x, -top.y) - rotation),
          cos(atan2(top.x, -top.y) - rotation),
        ).abs(),
        lessThan(.1),
      );
      // JSON remains valid after replacing the poisoned historical reference.
      final prefs = await SharedPreferences.getInstance();
      expect(
        jsonDecode(
          prefs.getString(CalibrationReferenceStorage.key)!,
        )['version'],
        2,
      );
    },
  );
  test(
    'Scoring rings resolve candidates when the coarse centre is inconclusive',
    () {
      final expected = BoardOutline(
        const Point(.5, .5),
        .34,
        .27,
        0,
        const Point(.5, .5),
      );
      final picture = boardImage(expected);
      img.fillCircle(
        picture,
        x: 350,
        y: 240,
        radius: 9,
        color: img.ColorRgb8(20, 135, 60),
      );
      img.fillCircle(
        picture,
        x: 350,
        y: 240,
        radius: 4,
        color: img.ColorRgb8(190, 25, 30),
      );
      final result = detectBoardOutline(img.encodePng(picture));
      expect((result.outline.bull - expected.bull).magnitude, lessThan(.01));
      expect(result.diagnostics!.bullCandidates.length, 2);
      expect(result.diagnostics!.geometryValid, isTrue);
    },
  );
  test(
    'A clearly central bull wins over a second candidate inside the coarse central region',
    () {
      final expected = BoardOutline(
        const Point(.5, .5),
        .34,
        .27,
        0,
        const Point(.5, .5),
      );
      final picture = boardImage(expected);
      img.fillCircle(
        picture,
        x: 380,
        y: 240,
        radius: 9,
        color: img.ColorRgb8(20, 135, 60),
      );
      img.fillCircle(
        picture,
        x: 380,
        y: 240,
        radius: 4,
        color: img.ColorRgb8(190, 25, 30),
      );
      final result = detectBoardOutline(img.encodePng(picture));
      expect((result.outline.bull - expected.bull).magnitude, lessThan(.01));
      expect(result.diagnostics!.bullCandidates.length, 2);
      expect(result.diagnostics!.geometryValid, isTrue);
    },
  );
  test('A bull-like logo near the board edge does not hide the real bull', () {
    final expected = BoardOutline(
      const Point(.5, .5),
      .34,
      .27,
      0,
      const Point(.5, .5),
    );
    final picture = boardImage(expected);
    img.fillCircle(
      picture,
      x: 480,
      y: 270,
      radius: 9,
      color: img.ColorRgb8(20, 135, 60),
    );
    img.fillCircle(
      picture,
      x: 480,
      y: 270,
      radius: 4,
      color: img.ColorRgb8(190, 25, 30),
    );
    final result = detectBoardOutline(img.encodePng(picture));
    expect((result.outline.bull - expected.bull).magnitude, lessThan(.01));
    expect(result.diagnostics!.bullCandidates.length, 2);
    expect(result.diagnostics!.geometryValid, isTrue);
  });
  test('Coloured number-ring marks cannot replace the scoring rings', () {
    final expected = BoardOutline(
      const Point(.5, .5),
      .30,
      .24,
      0,
      const Point(.5, .5),
    );
    final picture = boardImage(expected);
    for (var i = 0; i < 96; i++) {
      final angle = i * 2 * pi / 96;
      final p = expected.unrectify(Point(cos(angle) * 1.22, sin(angle) * 1.22));
      img.fillCircle(
        picture,
        x: (p.x * 639).round(),
        y: (p.y * 479).round(),
        radius: 3,
        color: i.isEven
            ? img.ColorRgb8(190, 25, 30)
            : img.ColorRgb8(20, 135, 60),
      );
    }
    final result = detectBoardOutline(img.encodePng(picture));
    expect(result.outline.major, closeTo(expected.major, .015));
    expect(result.outline.minor, closeTo(expected.minor, .015));
    expect(result.diagnostics!.tripleBins, greaterThanOrEqualTo(30));
  });
  test(
    'Rejected bull detection retains candidates and colour observations',
    () {
      final picture = boardImage(
        BoardOutline(const Point(.5, .5), .34, .27, 0, const Point(.5, .5)),
      );
      img.fillCircle(
        picture,
        x: 320,
        y: 240,
        radius: 15,
        color: img.ColorRgb8(30, 30, 30),
      );
      img.fillCircle(
        picture,
        x: 290,
        y: 240,
        radius: 9,
        color: img.ColorRgb8(20, 135, 60),
      );
      img.fillCircle(
        picture,
        x: 290,
        y: 240,
        radius: 4,
        color: img.ColorRgb8(190, 25, 30),
      );
      img.fillCircle(
        picture,
        x: 350,
        y: 240,
        radius: 9,
        color: img.ColorRgb8(20, 135, 60),
      );
      img.fillCircle(
        picture,
        x: 350,
        y: 240,
        radius: 4,
        color: img.ColorRgb8(190, 25, 30),
      );
      try {
        detectBoardOutline(img.encodePng(picture));
        fail('Two bull candidates must not authorize scoring.');
      } on CalibrationFailure catch (error) {
        expect(error.diagnostics, isNotNull);
        expect(
          error.diagnostics!.bullCandidates.length,
          greaterThanOrEqualTo(2),
        );
        expect(error.diagnostics!.colorSamples, isNotEmpty);
        expect(error.diagnostics!.geometryValid, isFalse);
      }
    },
  );
  test('Repositioned USB cameras still detect board geometry', () {
    for (var i = 1; i <= 3; i++) {
      final result = detectBoardOutline(
        File('test/fixtures/autoscoring/shifted_$i.png').readAsBytesSync(),
      );
      final bull = [
        const Point(149 / 316, 71 / 178),
        const Point(158 / 316, 72 / 178),
        const Point(144 / 316, 64 / 178),
      ][i - 1];
      expect(
        result.outline.bull.distanceTo(bull),
        lessThan(.025),
        reason: 'Camera $i',
      );
      expect(result.outline.major, inInclusiveRange(.24, .36));
      expect(result.outline.minor, inInclusiveRange(.22, .34));
    }
  });
  test('A blank number ring cannot inherit another cameras orientation', () {
    final reference = File(
      'test/fixtures/autoscoring/original_2.jpg',
    ).readAsBytesSync();
    final target = img.encodePng(
      boardImage(
        BoardOutline(const Point(.5, .5), .34, .27, 0, const Point(.5, .5)),
      ),
    );
    expect(
      () => calibrateFromReference(
        ReferenceCalibrationInput(
          target,
          reference,
          BoardCalibration(const [
            Point(.5, .1),
            Point(.9, .5),
            Point(.5, .9),
            Point(.1, .5),
          ]),
        ),
      ),
      throwsA(isA<CalibrationFailure>()),
    );
  });
  test(
    'Printed number ring transfers orientation from USB camera 2 to camera 1',
    () {
      final reference = File(
        'test/fixtures/autoscoring/original_2.jpg',
      ).readAsBytesSync();
      final target = File(
        'test/fixtures/autoscoring/repeat_1.jpg',
      ).readAsBytesSync();
      final sourceOutline = detectBoardOutline(reference).outline;
      final number = sourceOutline.rectify(const Point(337 / 1279, 550 / 719));
      final angle = atan2(number.x, -number.y);
      final calibration = BoardCalibration([
        for (var i = 0; i < 4; i++)
          sourceOutline.unrectify(
            Point(sin(angle + i * pi / 2), -cos(angle + i * pi / 2)),
          ),
      ]);
      final result = calibrateFromReference(
        ReferenceCalibrationInput(target, reference, calibration),
      );
      final projected = result.calibration.project(
        const Point(480 / 1279, 151 / 719),
      );
      expect(atan2(projected.x, -projected.y).abs(), lessThan(.08));
    },
  );
  test(
    'Inward-facing OCR tiles recover board orientation with fixed-size platform lists',
    () async {
      const channel = MethodChannel('calibration_test');
      var calls = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls++;
            if (calls < 10) return [];
            return List.of([
              for (final pair in [(20, 0), (6, 10), (3, 20), (11, 30)])
                {
                  'text': '${pair.$1}',
                  'x':
                      numberSheetTile * 8 -
                      (pair.$2 % 8 * numberSheetTile +
                          (numberSheetTile - 1) / 2) -
                      5,
                  'y':
                      numberSheetTile * 5 -
                      (pair.$2 ~/ 8 * numberSheetTile +
                          (numberSheetTile - 1) * .44) -
                      5,
                  'width': 10.0,
                  'height': 10.0,
                },
            ], growable: false);
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
      final outline = BoardOutline(
        const Point(.5, .5),
        .34,
        .27,
        0,
        const Point(.5, .5),
      );
      final result = await const WindowsAutomaticCalibrationService(
        channel: channel,
        useReferenceCache: false,
      ).calibrate(img.encodePng(boardImage(outline)));
      expect(calls, 10);
      expect(result.numberCount, 4);
      expect(
        BoardGeometry.score(
          result.calibration.project(
            outline.unrectify(const Point(0, -103 / 170)),
          ),
        ).label,
        'T20',
      );
    },
  );
  test('Camera images with red surround detect the board rings', () {
    for (var i = 0; i < 3; i++) {
      final bytes = File(
        'test/fixtures/autoscoring/camera_${i + 1}.png',
      ).readAsBytesSync();
      final result = detectBoardOutline(bytes);
      final bull = [
        const Point(149 / 314, 71 / 177),
        const Point(158 / 314, 72 / 177),
        const Point(143 / 314, 65 / 177),
      ][i];
      expect(result.outline.bull.distanceTo(bull), lessThan(.025));
      expect(result.outline.major, inInclusiveRange(.24, .36));
      expect(result.outline.minor, inInclusiveRange(.22, .34));
    }
  });
  for (var i = 1; i <= 3; i++) {
    test('Original USB camera $i detects the ring and bull', () {
      final result = detectBoardOutline(
        File('test/fixtures/autoscoring/original_$i.jpg').readAsBytesSync(),
      );
      expect(result.outline.major, inInclusiveRange(.24, .36));
      expect(result.outline.minor, inInclusiveRange(.22, .34));
    });
  }
  test(
    'Windows OCR deskew and quarter-turn boxes map to the same number location',
    () {
      // Known pixel location (50,10) in the unrotated original image.
      for (final rotation in [0, 90, 180, 270]) {
        final q = switch (rotation) {
          90 => const Point(90.0, 50.0),
          180 => const Point(50.0, 90.0),
          270 => const Point(10.0, 50.0),
          _ => const Point(50.0, 10.0),
        };
        const textAngle = 33.0;
        final a = -textAngle * pi / 180, dx = q.x - 50.5, dy = q.y - 50.5;
        final box = Point(
          50.5 + cos(a) * dx - sin(a) * dy,
          50.5 + sin(a) * dx + cos(a) * dy,
        );
        final numbers = readOcrBoardNumbers(
          [
            {
              'text': '20',
              'x': box.x - 5,
              'y': box.y - 4,
              'width': 10,
              'height': 8,
              'textAngle': textAngle,
            },
          ],
          rotation: rotation,
          width: 101,
          height: 101,
        );
        expect(numbers.single.value, 20);
        expect(numbers.single.position.x, closeTo(0, 1e-9));
        expect(numbers.single.position.y, closeTo(-1.12, 1e-9));
      }
    },
  );
  for (final parameters in [(0.0, 0.0), (0.65, .13), (-1.2, -.18)]) {
    test(
      'Auto ring and bull calibration with rotation ${parameters.$1} perspective ${parameters.$2}',
      () {
        final centre = const Point(.5, .5), angle = parameters.$1;
        final blank = BoardOutline(centre, .34, .27, angle, centre);
        final original = BoardOutline(
          centre,
          .34,
          .27,
          angle,
          blank.imagePoint(Point(parameters.$2, .04)),
        );
        final result = detectBoardOutline(img.encodePng(boardImage(original)));
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
        final labels = [
          for (var i = 0; i < 20; i++)
            BoardNumber(
              wheel[i],
              result.outline.rectify(
                original.unrectify(
                  Point(sin(i * pi / 10) * 1.2, -cos(i * pi / 10) * 1.2),
                ),
              ),
            ),
        ];
        final calibrated = resolveBoardOrientation(result.outline, labels);
        expect(calibrated.numberCount, 20);
        expect(
          calibrated.calibration.project(original.bull).magnitude,
          lessThan(2),
        );
        for (var i = 0; i < 20; i++) {
          final tip = original.unrectify(
            Point(sin(i * pi / 10) * 103 / 170, -cos(i * pi / 10) * 103 / 170),
          );
          expect(
            BoardGeometry.score(calibrated.calibration.project(tip)).label,
            'T${wheel[i]}',
          );
        }
      },
    );
  }
  test('Disk rectification is projective and invertible', () {
    final outline = BoardOutline(
      const Point(.48, .52),
      .32,
      .18,
      .75,
      const Point(.5, .55),
    );
    for (final q in [
      const Point(0.0, 0.0),
      const Point(.2, -.6),
      const Point(1.0, 0.0),
      const Point(0.0, 1.2),
    ]) {
      expect(
        outline.rectify(outline.unrectify(q)).distanceTo(q),
        lessThan(1e-9),
      );
    }
    expect(outline.rectify(outline.bull).magnitude, lessThan(1e-9));
  });
  test('No calibration without readable, consistent numbers', () {
    final outline = BoardOutline(
      const Point(.5, .5),
      .4,
      .3,
      0,
      const Point(.5, .5),
    );
    expect(
      () => resolveBoardOrientation(outline, []),
      throwsA(isA<CalibrationFailure>()),
    );
    expect(
      () => resolveBoardOrientation(outline, const [
        BoardNumber(20, Point(0, -1.2)),
        BoardNumber(6, Point(1.2, 0)),
      ]),
      throwsA(isA<CalibrationFailure>()),
    );
    final good = [
      for (final pair in [(20, 0), (6, 5), (3, 10), (11, 15)])
        BoardNumber(
          pair.$1,
          Point(sin(pair.$2 * pi / 10) * 1.2, -cos(pair.$2 * pi / 10) * 1.2),
        ),
    ];
    expect(
      resolveBoardOrientation(outline, [
        ...good,
        const BoardNumber(9, Point(0, -1.2)),
      ]).numberCount,
      4,
    );
  });
  test('Empty and clipped boards fail without generating markers', () {
    expect(
      () =>
          detectBoardOutline(img.encodePng(img.Image(width: 640, height: 480))),
      throwsA(isA<CalibrationFailure>()),
    );
    final outline = BoardOutline(
      const Point(.92, .5),
      .35,
      .27,
      0,
      const Point(.92, .5),
    );
    expect(
      () => detectBoardOutline(img.encodePng(boardImage(outline))),
      throwsA(isA<CalibrationFailure>()),
    );
  });
}
