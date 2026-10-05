import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dart_tournament_manager/features/autoscoring/domain/board_geometry.dart';
import 'package:dart_tournament_manager/features/autoscoring/domain/lens_distortion.dart';
import 'package:dart_tournament_manager/features/autoscoring/domain/dense_board_calibration.dart';
import 'package:dart_tournament_manager/features/autoscoring/domain/frame_detector.dart';
import 'package:dart_tournament_manager/features/autoscoring/domain/multi_camera_consensus.dart';
import 'package:dart_tournament_manager/features/autoscoring/domain/temporal_hit_decision.dart';
import 'package:dart_tournament_manager/features/autoscoring/domain/correction_analysis.dart';
import 'package:dart_tournament_manager/features/autoscoring/domain/detail_hit_refinement.dart';
import 'package:dart_tournament_manager/features/autoscoring/data/autoscoring_storage.dart';
import 'package:dart_tournament_manager/features/autoscoring/data/autoscore_diagnostic_export.dart';
import 'package:dart_tournament_manager/features/autoscoring/data/packed_gray_frame.dart';
import 'package:dart_tournament_manager/features/autoscoring/application/capture_autoscore_evidence.dart';
import 'autoscoring_automatic_counting_test.dart' show createController;

BoardCalibration calibration({LensDistortion lens = const LensDistortion()}) =>
    BoardCalibration(const [
      Point(.5, .1),
      Point(.9, .5),
      Point(.5, .9),
      Point(.1, .5),
    ], lens: lens);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'Captured evidence releases raw detail buffers and exports their original pixels',
    () {
      final c = createController([]);
      addTearDown(c.dispose);
      final pixels = Uint8List.fromList(List.generate(256, (i) => i));
      final detail = GrayFrame(16, 16, pixels);
      final low = GrayFrame(8, 8, Uint8List(64), detail: detail);
      for (final camera in c.cameras) {
        camera.snapshot = img.encodePng(img.Image(width: 16, height: 16));
        camera.lastReference = low;
        camera.emptyReference = low;
        camera.previous = low;
        camera.lastDetectionFrames = [low, low];
      }
      final evidence = captureAutoscoreEvidence(c)!;
      expect(evidence.cameras.first.before!.detail, isNull);
      expect(evidence.cameras.first.frames.first.detail, isNull);
      expect(
        identical(
          evidence.cameras.first.beforeDetail,
          evidence.cameras.last.emptyDetail,
        ),
        isTrue,
      );
      final archive = ZipDecoder().decodeBytes(
        const AutoscoreDiagnosticExport().encode(evidence, '20', '20'),
      );
      final png = img.decodePng(
        Uint8List.fromList(
          archive.findFile('kamera_1_sequenz_1_detail.png')!.content
              as List<int>,
        ),
      )!;
      expect(png.width, 16);
      expect(png.getPixel(5, 5).r, 85);
    },
  );
  test(
    'Packed detail evidence is lossless and shared references are reused',
    () {
      final frame = GrayFrame(
        320,
        320,
        Uint8List.fromList(List.generate(320 * 320, (i) => i % 256)),
      );
      final packed = PackedGrayFrame.fromFrame(frame);
      expect(packed.bytes.length, lessThan(frame.pixels.length / 10));
      expect(packed.unpack().pixels, frame.pixels);
      expect(identical(packed, PackedGrayFrame.fromFrame(frame)), isTrue);
    },
  );
  test(
    'Radial lens correction preserves project/unproject including the black rim',
    () {
      final c = calibration(
        lens: const LensDistortion(k1: .3, aspectRatio: 16 / 9),
      );
      for (final p in const [
        Point(0.0, 0.0),
        Point(25.0, -103.0),
        Point(-180.0, 80.0),
      ]) {
        expect(c.project(c.unproject(p)).distanceTo(p), lessThan(.00001));
      }
    },
  );
  test('Independent dense ring points recover radial distortion', () {
    final trueCal = calibration(lens: const LensDistortion(k1: .3));
    final initial = BoardCalibration(trueCal.points);
    final observations = [
      for (var sector = 0; sector < 20; sector++)
        for (final radius in [103.0, 166.0])
          (() {
            final q = Point(
              sin(sector * pi / 10) * radius,
              -cos(sector * pi / 10) * radius,
            );
            return CalibrationObservation(trueCal.unproject(q), q, sector);
          })(),
    ];
    final fit = fitDenseCalibration(initial, observations);
    expect(fit.metrics['applied'], isTrue);
    expect(fit.calibration.lens.k1, closeTo(.3, .03));
    for (var sector = 0; sector < 20; sector++) {
      final p = Point(
        sin((sector + .3) * pi / 10) * 140,
        -cos((sector + .3) * pi / 10) * 140,
      );
      expect(
        fit.calibration.project(trueCal.unproject(p)).distanceTo(p),
        lessThan(.1),
      );
    }
    expect(
      identical(
        fitDenseCalibration(initial, observations.take(8).toList()).calibration,
        initial,
      ),
      isTrue,
    );
  });
  test(
    'v1 camera calibration migrates and v2 preserves lens parameters',
    () async {
      SharedPreferences.setMockInitialValues({
        AutoscoringStorage.key: jsonEncode({
          'version': 1,
          'cameras': {
            'usb': [
              for (final p in calibration().points) [p.x, p.y],
            ],
          },
        }),
      });
      final storage = AutoscoringStorage();
      expect((await storage.load())['usb']!.lens.k1, 0);
      await storage.save({
        'usb': calibration(
          lens: const LensDistortion(k1: .2, aspectRatio: 16 / 9),
        ),
      });
      final loaded = (await storage.load())['usb']!;
      expect(loaded.lens.k1, .2);
      expect(loaded.lens.aspectRatio, 16 / 9);
    },
  );
  test('Original detail pixels refine a quantized low-resolution shaft', () {
    final cal = calibration();
    GrayFrame shaft(int size, int row, {GrayFrame? detail}) {
      final pixels = Uint8List(size * size);
      for (var x = (size * .3).round(); x < (size * .7).round(); x++) {
        for (var y = row - 1; y <= row + 1; y++) {
          pixels[y * size + x] = 180;
        }
      }
      return GrayFrame(size, size, pixels, detail: detail);
    }

    final lowEmpty = GrayFrame(480, 480, Uint8List(480 * 480));
    final detailEmpty = GrayFrame(1280, 1280, Uint8List(1280 * 1280));
    final before = GrayFrame(480, 480, lowEmpty.pixels, detail: detailEmpty);
    final coarse = const FrameDetector().axis(lowEmpty, shaft(480, 100), cal)!;
    final refined = const FrameDetector().axis(
      before,
      shaft(480, 100, detail: shaft(1280, 272)),
      cal,
    )!;
    final target = cal.project(const Point(.5, 272 / 1279));
    expect(refined.distance(target), lessThan(.1));
    expect(refined.distance(target), lessThan(coarse.distance(target)));
    final vertical = DartAxis(target, target + const Point(0.0, 100.0));
    final provisional = fuseAxes([coarse, vertical])!;
    final local = refineHitDetail(
      provisional,
      [before, before],
      [shaft(480, 100, detail: shaft(1280, 272)), shaft(480, 100)],
      [cal, cal],
      [coarse, vertical],
    );
    expect(local.applied, isTrue);
    expect(local.hit.point.distanceTo(target), lessThan(.1));
    final image = img.Image(width: 960, height: 540);
    final decoded = decodeCameraFrame(img.encodePng(image));
    expect(decoded.width, 480);
    expect(decoded.detail!.width, 960);
  });
  test(
    'Three independent cameras select consistent alternatives, not duplicate lines',
    () {
      const p = Point(10.0, -103.0);
      final truth = [
        DartAxis(p, p + const Point(100.0, 0.0), confidence: .95),
        DartAxis(p, p + const Point(0.0, 100.0), confidence: .95),
        DartAxis(p, p + const Point(100.0, 100.0), confidence: .95),
      ];
      final wrong = [
        DartAxis(const Point(0, 0), const Point(100, 0), confidence: .8),
        DartAxis(const Point(150, 0), const Point(150, 100), confidence: .8),
        DartAxis(const Point(200, 200), const Point(300, 100), confidence: .8),
      ];
      final chosen = chooseCameraConsensus([
        for (var i = 0; i < 3; i++) [wrong[i], truth[i]],
      ]);
      expect(chosen.hit!.point.distanceTo(p), lessThan(.0001));
      expect(chosen.hit!.views, 3);
      expect(chosen.alternativesUsed, isTrue);
      expect(chosen.hit!.needsReview, isTrue);
      expect(chooseCameraConsensus([truth, [], []]).hit, isNull);
      DartAxis line(Point<double> p, Point<double> direction) =>
          DartAxis(p, p + direction, confidence: .95);
      const a = Point(0.0, 0.0), b = Point(100.0, 100.0);
      final ambiguous = chooseCameraConsensus([
        [line(a, const Point(100, 0)), line(b, const Point(100, 0))],
        [line(b, const Point(0, 100)), line(a, const Point(0, 100))],
        [line(a, const Point(100, 100)), line(b, const Point(100, 100))],
      ]);
      expect(ambiguous.hit, isNull);
    },
  );
  test('Temporal decision is bounded and resets between throws', () {
    final decision = TemporalHitDecision();
    expect(decision.observe(const FusedHit(Point(0, -100), 0, 3)), isNull);
    expect(decision.observe(const FusedHit(Point(1, -100), 0, 3)), isNotNull);
    decision.reset();
    expect(decision.observe(const FusedHit(Point(-18, -103), 0, 2)), isNull);
    expect(decision.observe(const FusedHit(Point(-9, -103), 0, 2)), isNull);
    final hit = decision.observe(const FusedHit(Point(1, -103), 0, 2))!;
    expect(hit.point, const Point(-9.0, -103.0));
    expect(hit.forcedDecision, isTrue);
    expect(decision.selectedIndex, 1);
    decision.reset();
    expect(decision.observe(const FusedHit(Point(100, 0), 0, 2)), isNull);
  });
  test(
    'Correction statistics canonicalize axis signs and exclude unpositioned guesses',
    () {
      final analysis = analysePositionCorrections([
        const PositionCorrectionSample(Point(10, 20), Point(8, 16), [
          {'a': 1.0, 'b': 0.0, 'c': -8.0},
        ]),
        const PositionCorrectionSample(Point(10, 20), null, [
          {'a': -1.0, 'b': 0.0, 'c': 8.0},
        ]),
      ]);
      expect((analysis['xError'] as Map)['meanMillimetres'], 2);
      expect((analysis['yError'] as Map)['meanMillimetres'], 4);
      expect(
        ((analysis['cameras'] as List).first['signedAxisError']
            as Map)['meanMillimetres'],
        2,
      );
      expect(analysis['missingPositionCount'], 1);
      final old = correctionSampleFromReport({
        'schemaVersion': 3,
        'correctionPosition': {'xMillimetres': 10, 'yMillimetres': 20},
        'hit': {'xMillimetres': 8, 'yMillimetres': 16},
        'cameras': [],
      });
      expect(old!.expected, const Point(10.0, 20.0));
      expect(
        correctionSampleFromReport({'hit': {}, 'correctionPosition': null}),
        isNull,
      );
    },
  );
  test(
    'Diagnostic v5 retains higher resolution references, sequence and correction errors',
    () {
      final raw = img.encodePng(img.Image(width: 16, height: 16));
      final detail = GrayFrame(16, 16, Uint8List(256));
      final low = GrayFrame(8, 8, Uint8List(64), detail: detail);
      final evidence = AutoscoreEvidence(
        [
          AutoscoreCameraEvidence(
            raw,
            low,
            low,
            {
              'axis': {'a': 1.0, 'b': 0.0, 'c': -8.0},
            },
            frames: [low, low],
          ),
        ],
        {'xMillimetres': 8.0, 'yMillimetres': 16.0},
      );
      final archive = ZipDecoder().decodeBytes(
        const AutoscoreDiagnosticExport().encode(
          evidence,
          '20',
          'T20',
          correctionPosition: {'xMillimetres': 10.0, 'yMillimetres': 20.0},
        ),
      );
      expect(archive.findFile('kamera_1_vorher_detail.png'), isNotNull);
      expect(archive.findFile('kamera_1_sequenz_2_detail.png'), isNotNull);
      final report = jsonDecode(
        utf8.decode(
          archive.findFile('korrektur_auswertung.json')!.content as List<int>,
        ),
      );
      expect(report['currentCorrection']['xError']['meanMillimetres'], 2);
    },
  );
}
