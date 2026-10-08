import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_tournament_manager/features/autoscoring/domain/automatic_visit_reset.dart';
import 'package:dart_tournament_manager/features/autoscoring/domain/board_geometry.dart';
import 'package:dart_tournament_manager/features/autoscoring/domain/frame_detector.dart';
import 'package:dart_tournament_manager/features/autoscoring/domain/lens_distortion.dart';

void main() {
  test(
    'Actual settled frames release a transient first-dart removal latch',
    () {
      const root = 'test/fixtures/autoscoring/removal_1791461220924';
      final report =
          jsonDecode(File('$root/bericht.json').readAsStringSync()) as Map;
      List<GrayFrame> load(String suffix) => [
        for (var i = 1; i <= 3; i++)
          decodeCameraFrame(
            File('$root/kamera_${i}_$suffix.png').readAsBytesSync(),
          ),
      ];
      final empty = load('leer'), occupied = load('vorher');
      final calibrations = <BoardCalibration>[
        for (final meta in report['cameras'])
          BoardCalibration([
            for (final p in meta['calibration'])
              Point((p['x'] as num).toDouble(), (p['y'] as num).toDouble()),
          ], lens: LensDistortion.fromJson(meta['lens'] as Map)),
      ];
      final reset = AutomaticVisitReset();
      reset.observe(
        empty: empty,
        occupied: occupied,
        current: empty,
        stable: false,
        darts: 1,
        calibrations: calibrations,
      );
      expect(reset.waitingForEmpty, isTrue);
      var state = VisitResetState.waitingForEmpty;
      final trace = <Object?>[];
      for (var n = 0; n < 8; n++) {
        state = reset.observe(
          empty: empty,
          occupied: occupied,
          current: load('sequenz_${n + 1}'),
          stable: false,
          darts: 1,
          calibrations: calibrations,
        );
        trace.add({
          'frame': n,
          'state': state.name,
          'decision': reset.decisionMetrics,
          'cameras': reset.cameraMetrics,
        });
      }
      expect(trace.any((row) => (row as Map)['state'] == 'cleared'), isFalse);
      expect(state, VisitResetState.playing);
      expect(reset.waitingForEmpty, isFalse);
    },
  );
}
