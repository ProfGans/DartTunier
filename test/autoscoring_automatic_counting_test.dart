import 'dart:math';
import 'dart:typed_data';
import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_tournament_manager/features/autoscoring/application/autoscoring_controller.dart';
import 'package:dart_tournament_manager/features/autoscoring/domain/board_geometry.dart';
import 'package:dart_tournament_manager/features/autoscoring/domain/frame_detector.dart';
import 'package:dart_tournament_manager/features/scorer/domain/x01/x01_models.dart';

List<GrayFrame> frames(int darts, {bool hand = false, int spacing = 10}) => [
  for (var camera = 0; camera < 3; camera++)
    (() {
      final pixels = Uint8List(320 * 320);
      if (hand) pixels.fillRange(0, pixels.length, 180);
      for (var slot = 0; slot < darts; slot++) {
        for (var y = 1; y < 319; y++) {
          for (var x = 1; x < 319; x++) {
            final shaft = switch (camera) {
              0 => x >= 100 && x <= 210 && (y - 82 - slot * spacing).abs() <= 2,
              1 => y >= 50 && y <= 180 && (x - 159 - slot * spacing).abs() <= 2,
              _ => x >= 100 && x <= 230 && (y - (x - 77)).abs() <= 2,
            };
            if (shaft) pixels[y * 320 + x] = 180;
          }
        }
      }
      return GrayFrame(320, 320, pixels);
    })(),
];

AutoscoringController createController(List<DartThrowResult> counted) {
  final empty = frames(0);
  final c = AutoscoringController()
    ..automaticCounting = true
    ..onAutomaticThrow = (result) {
      counted.add(result);
      return true;
    }
    ..running = true;
  for (var i = 0; i < 3; i++) {
    c.cameras.add(
      AutoscoreCamera(
          CameraDescription(
            name: 'USB $i',
            lensDirection: CameraLensDirection.external,
            sensorOrientation: 0,
          ),
          i,
          1,
        )
        ..calibration = BoardCalibration(const [
          Point(.5, .1),
          Point(.9, .5),
          Point(.5, .9),
          Point(.1, .5),
        ])
        ..reference = empty[i]
        ..emptyReference = empty[i]
        ..previous = empty[i],
    );
  }
  return c;
}

void observe(
  AutoscoringController c,
  List<GrayFrame> capture, [
  int samples = 6,
]) {
  for (var i = 0; i < samples; i++) {
    c.processFrames(capture);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'Background motion does not lock the next visit after pulling darts',
    () {
      final counted = <DartThrowResult>[];
      final c = createController(counted);
      addTearDown(c.dispose);
      var clears = 0;
      c.onAutomaticVisitCleared = () => clears++;
      observe(c, frames(1));
      expect(counted.length, 1);
      List<GrayFrame> background(int darts) => [
        for (final original in frames(darts))
          GrayFrame(
            original.width,
            original.height,
            Uint8List.fromList([
              for (var p = 0; p < original.pixels.length; p++)
                p % 320 < 30 && p ~/ 320 < 30 ? 220 : original.pixels[p],
            ]),
          ),
      ];
      observe(c, background(0), 8);
      expect(clears, 1);
      expect(c.throws, isEmpty);
      expect(c.waitingForEmpty, isFalse);
      observe(c, background(1));
      expect(counted.length, 2);
    },
  );

  test(
    'Removal with changed exposure and background noise resets and accepts the next dart',
    () {
      final counted = <DartThrowResult>[];
      final c = createController(counted);
      addTearDown(c.dispose);
      var clears = 0;
      c.onAutomaticVisitCleared = () {
        clears++;
      };
      observe(c, frames(1));
      expect(counted.length, 1);
      List<GrayFrame> shifted(int darts) => [
        for (final original in frames(darts))
          GrayFrame(
            original.width,
            original.height,
            Uint8List.fromList([
              for (var i = 0; i < original.pixels.length; i++)
                i < 100 ? 220 : original.pixels[i] + 30,
            ]),
          ),
      ];
      observe(c, shifted(0), 8);
      expect(c.throws, isEmpty);
      expect(c.waitingForEmpty, isFalse);
      expect(clears, 1);
      expect(
        c.cameras.every(
          (camera) =>
              camera.lastAcceptedAxis == null && camera.detectedAxis == null,
        ),
        isTrue,
      );
      observe(c, shifted(1));
      expect(counted.length, 2);
      expect(c.throws.length, 1);
    },
  );
  test(
    'Bouncer counts zero once, survives an empty board, and the next dart is recognized',
    () async {
      final counted = <DartThrowResult>[];
      final c = createController(counted);
      addTearDown(c.dispose);
      c.processFrames(frames(1));
      observe(c, frames(0));
      expect(counted.single, same(AutoscoringController.bouncerThrow));
      expect(c.throws.length, 1);
      observe(c, frames(0));
      expect(counted.length, 1);
      observe(c, frames(1));
      expect(counted.length, 2);
      observe(c, frames(0));
      expect(c.throws, isEmpty);
      expect(c.pending, isNull);
      expect(
        c.cameras.every(
          (camera) =>
              camera.lastReference == null &&
              camera.lastAcceptedAxis == null &&
              camera.changedPixels.isEmpty,
        ),
        isTrue,
      );
      await c.stop();
    },
  );
  test(
    'An unresolved stable dart is reported once and never mixed into the next dart',
    () async {
      final counted = <DartThrowResult>[];
      final c = createController(counted);
      addTearDown(c.dispose);
      final blocked = [
        for (var camera = 0; camera < 3; camera++)
          (() {
            final pixels = Uint8List(320 * 320);
            for (var y = 150; y < 170; y++) {
              for (var x = 150; x < 170; x++) {
                pixels[y * 320 + x] = 180;
              }
            }
            return GrayFrame(320, 320, pixels);
          })(),
      ];
      observe(c, blocked, 8);
      expect(counted.single, same(AutoscoringController.unresolvedThrow));
      observe(c, blocked, 8);
      expect(counted.length, 1);
      observe(c, frames(0, hand: true), 8);
      expect(counted.length, 1);
      await c.stop();
    },
  );
  test(
    'Two stable cameras recognize a dart while the third view keeps moving',
    () async {
      final counted = <DartThrowResult>[];
      final c = createController(counted);
      addTearDown(c.dispose);
      final dart = frames(1);
      for (var sample = 0; sample < 3; sample++) {
        c.processFrames([
          dart[0],
          dart[1],
          GrayFrame(
            320,
            320,
            Uint8List.fromList(List.filled(320 * 320, sample.isEven ? 180 : 0)),
          ),
        ]);
      }
      expect(counted.single.label, 'T20');
      expect(c.lastHit!.views, 2);
      await c.stop();
    },
  );
  test(
    'Reported missing dart becomes the reference and is not counted twice',
    () async {
      final counted = <DartThrowResult>[];
      final c = createController(counted);
      addTearDown(c.dispose);
      final current = frames(1);
      for (var i = 0; i < 3; i++) {
        c.cameras[i].previous = current[i];
      }
      expect(
        c.recordMissedThrow(BoardGeometry.score(const Point(0, -103))),
        isTrue,
      );
      observe(c, current);
      expect(counted, isEmpty);
      expect(c.throws.length, 1);
      observe(c, frames(2));
      expect(counted.length, 1);
      expect(c.throws.length, 2);
      observe(c, frames(0));
      expect(c.throws, isEmpty);
      await c.stop();
    },
  );
  test(
    'Four overlapping darts are counted once each in the unrestricted tester',
    () async {
      final counted = <DartThrowResult>[];
      final c = createController(counted)..automaticVisitDartLimit = null;
      addTearDown(c.dispose);
      for (var darts = 1; darts <= 4; darts++) {
        // Five-pixel shafts offset by just one pixel leave a narrow new edge.
        observe(c, frames(darts, spacing: 1), 3);
        expect(counted.length, darts);
        observe(c, frames(darts, spacing: 1), 3);
        expect(counted.length, darts);
      }
      expect(c.waitingForEmpty, isFalse);
      observe(c, frames(3, spacing: 1));
      expect(counted.length, 4);
      expect(c.waitingForEmpty, isTrue);
      observe(c, frames(0));
      expect(c.throws, isEmpty);
      await c.stop();
    },
  );
  test(
    'Counts real detector output once, waits for removal and starts another visit',
    () async {
      final counted = <DartThrowResult>[];
      final c = createController(counted);
      var cleared = 0;
      c.onAutomaticVisitCleared = () => cleared++;
      observe(c, frames(1));
      expect(counted.single.label, 'T20');
      expect(c.pending, isNull);
      expect(c.lastHit, isNotNull);
      expect(
        c.cameras.where((camera) => camera.lastAcceptedAxis != null).length,
        greaterThanOrEqualTo(2),
      );
      observe(c, frames(1));
      expect(counted.length, 1);
      observe(c, frames(2));
      observe(c, frames(3));
      expect(counted.length, 3);
      expect(c.running, isTrue);
      observe(c, frames(3));
      expect(c.waitingForEmpty, isTrue);
      observe(c, frames(2));
      observe(c, frames(0, hand: true));
      expect(cleared, 0);
      expect(counted.length, 3);
      expect(c.waitingForEmpty, isTrue);
      observe(c, frames(0));
      expect(c.waitingForEmpty, isFalse);
      expect(c.throws, isEmpty);
      expect(cleared, 1);
      observe(c, frames(0));
      expect(cleared, 1);
      expect(c.lastHit, isNull);
      expect(
        c.cameras.every((camera) => camera.lastAcceptedAxis == null),
        isTrue,
      );
      observe(c, frames(1));
      expect(counted.length, 4);
      await c.stop();
      c.dispose();
    },
  );
  test(
    'Early removal also resets automatically without counting the removed shaft',
    () async {
      final counted = <DartThrowResult>[];
      final c = createController(counted);
      observe(c, frames(1));
      observe(c, frames(0));
      expect(counted.length, 1);
      expect(c.throws, isEmpty);
      observe(c, frames(1));
      expect(counted.length, 2);
      await c.stop();
      c.dispose();
    },
  );
  for (final darts in [1, 2]) {
    test(
      'Removal after $darts counted darts waits for a moving third view and resets',
      () async {
        final counted = <DartThrowResult>[];
        final c = createController(counted);
        addTearDown(c.dispose);
        var clears = 0;
        c.onAutomaticVisitCleared = () => clears++;
        for (var dart = 1; dart <= darts; dart++) {
          observe(c, frames(dart));
        }
        expect(counted.length, darts);
        // Two cameras already see empty; the third still sees a hand or shaft.
        c.processFrames([frames(0)[0], frames(0)[1], frames(1, hand: true)[2]]);
        expect(c.waitingForEmpty, isTrue);
        expect(c.pending, isNull);
        expect(counted.length, darts);
        expect(clears, 0);
        observe(c, frames(0), 8);
        expect(clears, 1);
        expect(c.throws, isEmpty);
        expect(c.waitingForEmpty, isFalse);
        expect(c.pending, isNull);
        expect(c.lastHit, isNull);
        observe(c, frames(1));
        expect(counted.length, darts + 1);
        await c.stop();
      },
    );
  }

  test('Manual scoring still pauses for confirmation', () async {
    final counted = <DartThrowResult>[];
    final c = createController(counted)..automaticCounting = false;
    observe(c, frames(1));
    expect(c.pending, isNotNull);
    expect(c.running, isFalse);
    expect(counted, isEmpty);
    await c.stop();
    c.dispose();
  });
}
