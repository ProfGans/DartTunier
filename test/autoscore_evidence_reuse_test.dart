import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_tournament_manager/features/autoscoring/domain/board_geometry.dart';
import 'package:dart_tournament_manager/features/autoscoring/domain/frame_detector.dart';
import 'package:dart_tournament_manager/features/autoscoring/domain/lens_distortion.dart';
import 'package:dart_tournament_manager/features/scorer/domain/x01/x01_models.dart';
import 'autoscoring_automatic_counting_test.dart' show createController;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('Local detail corrects the recorded D19 to D3 exactly once', () {
    const root = 'test/fixtures/autoscoring/october_double';
    final report =
        jsonDecode(File('$root/bericht.json').readAsStringSync()) as Map;
    final accepted = <DartThrowResult>[];
    final controller = createController(accepted);
    addTearDown(controller.dispose);
    final current = <GrayFrame>[];
    expect(controller.captureDelay.inMilliseconds, 80);
    for (var i = 0; i < 3; i++) {
      final metadata = report['cameras'][i];
      final cal = BoardCalibration(
        [
          for (final p in metadata['calibration'])
            Point((p['x'] as num).toDouble(), (p['y'] as num).toDouble()),
        ],
        lens: LensDistortion(
          k1: (metadata['lens']['k1'] as num).toDouble(),
          aspectRatio: (metadata['lens']['aspectRatio'] as num).toDouble(),
        ),
      );
      GrayFrame load(String suffix) => decodeCameraFrame(
        File('$root/kamera_${i + 1}_$suffix.png').readAsBytesSync(),
      );
      final before = load('letzter_vorher_detail'),
          after = load('sequenz_3_detail');
      current.add(after);
      final reused = const FrameDetector().candidates(before, after, cal);
      final uncached = const FrameDetector(
        reuseEvidence: false,
      ).candidates(before, after, cal);
      expect(reused.length, uncached.length);
      for (var j = 0; j < reused.length; j++) {
        expect(reused[j].a, uncached[j].a);
        expect(reused[j].b, uncached[j].b);
        expect(reused[j].c, uncached[j].c);
        expect(reused[j].confidence, uncached[j].confidence);
      }
      controller.cameras[i]
        ..calibration = cal
        ..reference = before
        ..emptyReference = load('leer_detail')
        ..previous = after
        ..stable = 2;
    }
    controller.processFrames(current);
    expect(controller.captureDelay.inMilliseconds, 20);
    for (var i = 0; i < 7; i++) {
      controller.processFrames(current);
    }
    expect(accepted.single.label, 'D3');
    expect(controller.lastHit!.views, 3);
    expect(controller.processingMilliseconds, greaterThan(0));
  });
  test('Evidence is invalidated when a frame becomes the new reference', () {
    final cal = BoardCalibration(const [
      Point(.5, .1),
      Point(.9, .5),
      Point(.5, .9),
      Point(.1, .5),
    ]);
    final empty = GrayFrame(100, 100, Uint8List(10000));
    final pixels = Uint8List(10000);
    for (var x = 30; x < 70; x++) {
      pixels[40 * 100 + x] = 180;
    }
    final current = GrayFrame(100, 100, pixels);
    const detector = FrameDetector();
    expect(detector.axis(empty, current, cal), isNotNull);
    expect(detector.axis(current, current, cal), isNull);
    expect(detector.axis(empty, current, cal), isNotNull);
  });
}
