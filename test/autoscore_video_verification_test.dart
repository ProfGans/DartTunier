import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dart_tournament_manager/features/autoscoring/domain/video_frame_synchronizer.dart';
import 'package:dart_tournament_manager/features/autoscoring/domain/verification_summary.dart';
import 'package:dart_tournament_manager/features/autoscoring/domain/spatial_board_contact.dart';
import 'package:dart_tournament_manager/features/autoscoring/domain/dart_tip_detection.dart';
import 'package:dart_tournament_manager/features/autoscoring/domain/board_geometry.dart';
import 'package:dart_tournament_manager/features/autoscoring/domain/frame_detector.dart';
import 'package:dart_tournament_manager/features/autoscoring/data/windows_video_source.dart';
import 'package:dart_tournament_manager/features/autoscoring/data/autoscore_setup_store.dart';
import 'package:dart_tournament_manager/features/autoscoring/application/decode_video_frames.dart';
import 'package:dart_tournament_manager/features/autoscoring/application/autoscore_demo_controller.dart';
import 'package:dart_tournament_manager/features/scorer/domain/x01/x01_rules.dart';

CameraVideoFrame frame(int id, int time, int sequence) =>
    CameraVideoFrame(id, time, sequence, 1, 1, Uint8List.fromList([255, 0, 0]));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'Three cameras match by timestamp, discard old and duplicate frames',
    () {
      final sync = VideoFrameSynchronizer([1, 2, 3]);
      sync.add(frame(1, 0, 1));
      sync.add(frame(2, 100000, 1));
      sync.add(frame(3, 110000, 1));
      expect(sync.take(), isNull);
      expect(sync.discarded, 1);
      sync.add(frame(1, 105000, 2));
      sync.add(frame(1, 105000, 2));
      final batch = sync.take()!;
      expect(batch.map((f) => f.cameraId), [1, 2, 3]);
      expect(sync.lastSkewUs, 10000);
      expect(sync.take(), isNull);
    },
  );
  test('Per-camera backlog is bounded and malformed pixels are rejected', () {
    final sync = VideoFrameSynchronizer([1, 2, 3]);
    for (var i = 0; i < 10; i++) {
      sync.add(frame(1, i, i));
    }
    expect(sync.discarded, 4);
    expect(
      () => CameraVideoFrame.fromMap({
        'cameraId': 1,
        'timestampUs': 1,
        'sequence': 1,
        'width': 2,
        'height': 2,
        'rgb': Uint8List(3),
      }),
      throwsFormatException,
    );
  });
  test('Video decoder retains real RGB, luminance and capture time', () {
    final result = decodeVideoFrames([frame(1, 12345, 7)]).single;
    expect(result.pixels.single, 76);
    expect(result.timestampUs, 12345);
    expect(result.sequence, 7);
    final pixel = img.decodeJpg(result.colorImage!)!.getPixel(0, 0);
    expect(pixel.r, greaterThan(230));
    expect(pixel.g, lessThan(20));
    expect(pixel.b, lessThan(20));
  });
  test(
    'Tip detection locates changed shaft endpoint and rejects distant noise',
    () {
      final calibration = BoardCalibration(const [
        BoardPoint(.5, .1),
        BoardPoint(.9, .5),
        BoardPoint(.5, .9),
        BoardPoint(.1, .5),
      ]);
      final before = GrayFrame(200, 200, Uint8List(40000));
      final pixels = Uint8List(40000);
      for (var y = 65; y <= 110; y++) {
        for (var x = 99; x <= 101; x++) {
          pixels[y * 200 + x] = 180;
        }
      }
      final after = GrayFrame(200, 200, pixels);
      final axis = DartAxis(
        const BoardPoint(0, -100),
        const BoardPoint(0, 100),
      );
      final expected = calibration.project(
        const BoardPoint(100 / 199, 65 / 199),
      );
      final tip = detectDartTip(before, after, calibration, axis, expected);
      expect(tip, isNotNull);
      expect(tip!.board.distanceTo(expected), lessThan(3));
      expect(
        detectDartTip(before, before, calibration, axis, expected),
        isNull,
      );
      expect(
        detectDartTip(
          before,
          after,
          calibration,
          axis,
          const BoardPoint(150, 0),
        ),
        isNull,
      );
    },
  );
  test(
    'Capture backlog keeps newest three distinct synchronized observations',
    () async {
      const channel = MethodChannel('test/autoscore/backlog');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (call.method == 'configure') return true;
            return [
              for (var id = 1; id <= 3; id++)
                for (var n = 1; n <= 6; n++)
                  {
                    'cameraId': id,
                    'timestampUs': n * 33333 + id * 1000,
                    'sequence': n,
                    'width': 1,
                    'height': 1,
                    'rgb': Uint8List(3),
                  },
            ];
          });
      final source = WindowsVideoSource(channel: channel);
      await source.configure([1, 2, 3]);
      final batches = await source.read();
      expect(batches.map((b) => b.first.sequence), [4, 5, 6]);
      expect(batches.every((b) => b.length == 3), true);
      expect(source.backlogDropped, 3);
      expect(
        await source.read(),
        isEmpty,
      ); // Duplicate images are not evidence.
      await source.close();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    },
  );
  test(
    'Native channel delivers matched batches and releases capture',
    () async {
      const channel = MethodChannel('test/autoscore/video');
      final calls = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call.method);
            if (call.method == 'configure') return true;
            return [
              for (var id = 1; id <= 3; id++)
                {
                  'cameraId': id,
                  'timestampUs': id * 1000,
                  'sequence': 1,
                  'width': 1,
                  'height': 1,
                  'rgb': Uint8List(3),
                  'dropped': id,
                },
            ];
          });
      final source = WindowsVideoSource(channel: channel);
      expect(await source.configure([1, 2, 3]), true);
      expect((await source.read()).single.length, 3);
      expect(source.nativeDropped, 6);
      await source.close();
      expect(source.active, false);
      expect(calls, ['configure', 'read', 'configure']);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    },
  );
  test(
    'Pulling unreviewed darts does not inflate independent validation',
    () async {
      final store = AutoscoreSetupStore();
      await store.load();
      store.startValidationSeries(store.active.id);
      final demo = AutoscoreDemoController(setupStore: store);
      demo.add(const X01Rules().createSingle(20));
      demo.reset();
      expect(store.active.correct, 1);
      expect(store.active.independentlyReviewed, 0);
      expect(store.validationSummary(store.active.id).attempts, 1);
      demo.confirm(0);
      expect(store.active.verifiedCorrect, 1);
      demo.markFalsePositive(0);
      expect(store.active.verifiedCorrect, 0);
      expect(store.active.verifiedIncorrect, 1);
      expect(store.active.verifiedExtra, 1);
      demo.markFalsePositive(0);
      expect(store.active.verifiedExtra, 1);
      await store.flush();
      final restored = AutoscoreSetupStore();
      await restored.load();
      expect(restored.active.verifiedExtra, 1);
      expect(restored.validationSummary(restored.active.id).incorrect, 1);
      store.startValidationSeries(store.active.id);
      expect(store.validationSummary(store.active.id).attempts, 0);
      expect(store.active.verifiedExtra, 1);
      demo.dispose();
      store.dispose();
      restored.dispose();
    },
  );
  test(
    'False detection disappears from visit; missing throws count as errors',
    () async {
      final store = AutoscoreSetupStore();
      await store.load();
      final demo = AutoscoreDemoController(setupStore: store);
      demo.add(const X01Rules().createSingle(20));
      demo.markFalsePositive(0);
      expect(demo.throws, isEmpty);
      final missed = store.record(
        missing: true,
        detectedLabel: 'Nicht erkannt',
      );
      store.verify(missed, correct: false, missing: true, actualLabel: 'D20');
      store.verify(missed, correct: false, missing: true, actualLabel: 'D20');
      expect(store.active.verifiedIncorrect, 2);
      expect(store.active.verifiedMissing, 1);
      store.resetStatistics(store.active.id);
      store.verify(missed, correct: true);
      expect(store.active.independentlyReviewed, 0);
      demo.dispose();
      store.dispose();
    },
  );
  test('Legacy setup data migrate without invented verification', () async {
    final store = AutoscoreSetupStore();
    await store.load();
    final legacy = store.active.toJson();
    SharedPreferences.setMockInitialValues({
      AutoscoreSetupStore.key: jsonEncode({
        'version': 1,
        'activeId': 'default',
        'setups': [legacy],
      }),
    });
    final restored = AutoscoreSetupStore();
    await restored.load();
    expect(restored.loaded, true);
    expect(restored.active.independentlyReviewed, 0);
    restored.dispose();
    store.dispose();
  });
  test(
    '99.5 target requires complete sufficiently large independent series',
    () {
      expect(const VerificationSummary(100, 100, 0).supportsTarget, false);
      expect(
        const VerificationSummary(600, 600, 0).lowerBoundPercent,
        closeTo(99.502, .001),
      );
      expect(const VerificationSummary(600, 600, 0).supportsTarget, true);
      expect(const VerificationSummary(601, 600, 0).supportsTarget, false);
      expect(const VerificationSummary(600, 599, 1).supportsTarget, false);
      expect(const VerificationSummary(0, 0, 0).lowerBoundPercent, 0);
    },
  );
  test(
    'Three rays identify raised contact near existing dart; two never suffice',
    () {
      const target = Point3(10, 20, -50);
      final poses = [
        for (final x in [-200.0, 0.0, 200.0])
          CameraBoardPose(
            Point3(x, 100, -500),
            const Point3(1, 0, 0),
            const Point3(0, 1, 0),
            const Point3(0, 0, 1),
            1,
            1,
          ),
      ];
      final tips = [
        for (final pose in poses)
          DartTipObservation(
            BoardPoint(
              .5 + (target.x - pose.centre.x) / (target.z - pose.centre.z),
              .5 + (target.y - pose.centre.y) / (target.z - pose.centre.z),
            ),
            const BoardPoint(10, 20),
            .99,
          ),
      ];
      final contact = locateSpatialContact(poses, tips, [
        const BoardPoint(10, 20),
      ])!;
      expect(contact.point.z, closeTo(-50, .0001));
      expect(contact.residual, lessThan(.0001));
      expect(contact.robinHood, true);
      expect(locateSpatialContact(poses, [tips[0], tips[1], null], []), isNull);
      expect(
        locateSpatialContact(poses, tips, [
          const BoardPoint(100, 100),
        ])!.robinHood,
        false,
      );
    },
  );
  test(
    'Metric board pose recovers known camera geometry and rejects frontal ambiguity',
    () {
      final sa = math.sin(.35),
          ca = math.cos(.35),
          sb = math.sin(.5),
          cb = math.cos(.5);
      final r1 = Point3(cb, sa * sb, -ca * sb);
      final r2 = Point3(0, ca, sa);
      final r3 = Point3(sb, -sa * cb, ca * cb);
      const t = Point3(40, 10, 650);
      final points = [
        for (final p in const [
          BoardPoint(0, -170),
          BoardPoint(170, 0),
          BoardPoint(0, 170),
          BoardPoint(-170, 0),
        ])
          (() {
            final camera = r1 * p.x + r2 * p.y + t;
            return BoardPoint(
              .5 + camera.x / camera.z,
              .5 + camera.y / camera.z * 4 / 3,
            );
          })(),
      ];
      final pose = estimateBoardPose(
        BoardCalibration(points),
        aspectRatio: 4 / 3,
      )!;
      final expected = Point3(-r1.dot(t), -r2.dot(t), -r3.dot(t));
      expect((pose.centre - expected).length, lessThan(.0001));
      expect(pose.focal, closeTo(1, .0001));
      expect(
        estimateBoardPose(
          BoardCalibration(const [
            BoardPoint(.5, .1),
            BoardPoint(.9, .5),
            BoardPoint(.5, .9),
            BoardPoint(.1, .5),
          ]),
        ),
        isNull,
      );
    },
  );
}
