import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_tournament_manager/features/autoscoring/domain/board_geometry.dart';
import 'package:dart_tournament_manager/features/autoscoring/domain/frame_detector.dart';
import 'package:dart_tournament_manager/features/autoscoring/domain/lens_distortion.dart';
import 'package:dart_tournament_manager/features/autoscoring/domain/temporal_hit_decision.dart';
import 'package:dart_tournament_manager/features/scorer/domain/x01/x01_models.dart';
import 'autoscoring_automatic_counting_test.dart' show createController;
import 'autoscore_new_video_corrections_test.dart'
    show EndpointReplayController;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final sample in [('42', 'T5'), ('20', '20'), ('183', '20')]) {
    test(
      'Real sequence ${sample.$1} counts ${sample.$2} without correction input',
      () {
        final root = 'test/fixtures/autoscoring/new_video/case_${sample.$1}';
        final report =
            jsonDecode(File('$root/bericht.json').readAsStringSync()) as Map;
        final seed = createController([]);
        final counted = <DartThrowResult>[];
        final c = EndpointReplayController()
          ..running = true
          ..automaticCounting = true
          ..onAutomaticThrow = (hit) {
            counted.add(hit);
            return true;
          };
        c.cameras.addAll(seed.cameras);
        seed.cameras.clear();
        seed.dispose();
        addTearDown(c.dispose);
        GrayFrame load(int i, String name, [int? time]) {
          final low = decodeCameraFrame(
            File('$root/kamera_${i + 1}_$name.png').readAsBytesSync(),
          );
          final high = decodeCameraFrame(
            File('$root/kamera_${i + 1}_${name}_detail.png').readAsBytesSync(),
          );
          return GrayFrame(
            low.width,
            low.height,
            low.pixels,
            detail: high.detail ?? high,
            timestampUs: time,
          );
        }

        for (var i = 0; i < 3; i++) {
          final meta = report['cameras'][i] as Map;
          final before = load(i, 'letzter_vorher');
          c.cameras[i]
            ..reference = before
            ..previous = before
            ..emptyReference = load(i, 'leer')
            ..calibration = BoardCalibration([
              for (final p in meta['calibration'])
                Point((p['x'] as num).toDouble(), (p['y'] as num).toDouble()),
            ], lens: LensDistortion.fromJson(meta['lens'] as Map));
        }
        late List<GrayFrame> last;
        for (var n = 0; n < 8; n++) {
          last = [
            for (var i = 0; i < 3; i++)
              load(
                i,
                'sequenz_${n + 1}',
                report['cameras'][i]['frameTimestampsMicroseconds'][n] as int,
              ),
          ];
          c.processFrames(last);
        }
        for (var n = 0; n < 4; n++) {
          c.processFrames(last);
        }
        expect(counted.map((h) => h.label), [sample.$2]);
        expect(c.running, true);
        expect(c.waitingForEmpty, false);
      },
    );
  }
  for (final support in [2, 3]) {
    test(
      'Deadline favors independent three-view support, supplied support $support',
      () {
        final engine = TemporalHitDecision();
        const wrong = FusedHit(Point(-72, -144), 0, 2, forcedDecision: true);
        const supported = FusedHit(Point(9, -96), 1.4, 2, forcedDecision: true);
        expect(engine.observe(wrong), isNull);
        expect(engine.observe(supported, supportingViews: support), isNull);
        final result = engine.observe(
          const FusedHit(Point(-77, -142), 0, 2, forcedDecision: true),
        );
        expect(result, isNotNull);
        expect(engine.selectedIndex, support == 3 ? 1 : 0);
      },
    );
  }
}
