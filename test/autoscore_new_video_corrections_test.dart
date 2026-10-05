import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_tournament_manager/features/autoscoring/domain/board_geometry.dart';
import 'package:dart_tournament_manager/features/autoscoring/domain/frame_detector.dart';
import 'package:dart_tournament_manager/features/autoscoring/domain/lens_distortion.dart';
import 'package:dart_tournament_manager/features/autoscoring/domain/multi_camera_consensus.dart';
import 'package:dart_tournament_manager/features/autoscoring/application/autoscoring_controller.dart';
import 'package:dart_tournament_manager/features/scorer/domain/x01/x01_models.dart';
import 'autoscoring_automatic_counting_test.dart' show createController;

class EndpointReplayController extends AutoscoringController {
  @override
  bool get continuousVideo => true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final sample in [('5', 'T1'), ('97', '20')]) {
    test(
      'Recorded video correction ${sample.$1} counts ${sample.$2} exactly once',
      () {
        final root = 'test/fixtures/autoscoring/new_video/case_${sample.$1}';
        final report =
            jsonDecode(File('$root/bericht.json').readAsStringSync()) as Map;
        final accepted = <DartThrowResult>[];
        final seed = createController([]);
        final c = EndpointReplayController()
          ..automaticCounting = true
          ..running = true
          ..onAutomaticThrow = (result) {
            accepted.add(result);
            return true;
          };
        c.cameras.addAll(seed.cameras);
        seed.cameras.clear();
        seed.dispose();
        addTearDown(c.dispose);
        final current = <GrayFrame>[];
        for (var i = 0; i < 3; i++) {
          GrayFrame load(String suffix) => decodeCameraFrame(
            File('$root/kamera_${i + 1}_$suffix.png').readAsBytesSync(),
          );
          final before = load('letzter_vorher_detail');
          final frame = load('sequenz_7_detail');
          current.add(frame);
          c.cameras[i]
            ..reference = before
            ..previous = frame
            ..emptyReference = load('leer_detail')
            ..stable = 2
            ..calibration = BoardCalibration(
              [
                for (final p in report['cameras'][i]['calibration'])
                  Point((p['x'] as num).toDouble(), (p['y'] as num).toDouble()),
              ],
              lens: LensDistortion.fromJson(
                report['cameras'][i]['lens'] as Map,
              ),
            );
        }
        for (var n = 0; n < 10; n++) {
          c.processFrames(current);
        }
        expect(accepted.map((a) => a.label), [sample.$2]);
      },
    );
  }
  test(
    'Contradictory rim-only line cannot displace two strong inner shafts',
    () {
      const point = Point(0.0, -115.0);
      final a = DartAxis(point, point + const Point(10, 5), confidence: .95);
      final b = DartAxis(point, point + const Point(-5, 10), confidence: .95);
      final rim = DartAxis(
        const Point(180, 0),
        const Point(180, 100),
        confidence: .99,
        outerRimOnly: true,
      );
      final result = chooseCameraConsensus([
        [a],
        [rim],
        [b],
      ]);
      expect(result.hit!.point.distanceTo(point), lessThan(.0001));
      expect(result.hit!.views, 2);
      expect(result.hit!.needsReview, true);
      expect(result.axes[1], isNull);
      final generic = DartAxis(
        const Point(180, 0),
        const Point(180, 100),
        confidence: .99,
      );
      expect(
        chooseCameraConsensus([
          [a],
          [generic],
          [b],
        ]).hit,
        isNull,
      );
    },
  );
}
