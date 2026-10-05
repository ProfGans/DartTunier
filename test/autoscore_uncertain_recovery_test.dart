import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:dart_tournament_manager/features/autoscoring/domain/board_frame_alignment.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_tournament_manager/features/autoscoring/domain/board_geometry.dart';
import 'package:dart_tournament_manager/features/autoscoring/domain/frame_detector.dart';
import 'package:dart_tournament_manager/features/autoscoring/domain/lens_distortion.dart';
import 'package:dart_tournament_manager/features/autoscoring/domain/uncertain_hit_recovery.dart';

void main() {
  test(
    'Occluded case 126 requires distinct frames and independent third camera',
    () {
      const root = 'test/fixtures/autoscoring/new_video/case_126';
      final report =
          jsonDecode(File('$root/bericht.json').readAsStringSync()) as Map;
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

      final before = [for (var i = 0; i < 3; i++) load(i, 'letzter_vorher')];
      final empty = [for (var i = 0; i < 3; i++) load(i, 'leer')];
      final calibrations = [
        for (var i = 0; i < 3; i++)
          BoardCalibration(
            [
              for (final p in report['cameras'][i]['calibration'])
                Point((p['x'] as num).toDouble(), (p['y'] as num).toDouble()),
            ],
            lens: LensDistortion.fromJson(report['cameras'][i]['lens'] as Map),
          ),
      ];
      final pixels = Uint8List(before[0].pixels.length);
      for (var y = 0; y < before[0].height; y++) {
        for (var x = 1; x < before[0].width; x++) {
          pixels[y * before[0].width + x] =
              before[0].pixels[y * before[0].width + x - 1];
        }
      }
      final shifted = GrayFrame(before[0].width, before[0].height, pixels);
      final alignment = alignBoardFrame(
        before[0],
        shifted,
        empty[0],
        calibrations[0],
      );
      expect(alignment.applied, true);
      expect(alignment.dx, closeTo(1, .15));
      expect(alignment.dy, closeTo(0, .15));
      expect(
        alignBoardFrame(
          before[0],
          before[0],
          empty[0],
          calibrations[0],
        ).applied,
        false,
      );
      final first = [
        for (var i = 0; i < 3; i++)
          load(
            i,
            'sequenz_7',
            report['cameras'][i]['frameTimestampsMicroseconds'][6] as int,
          ),
      ];
      final second = [
        for (var i = 0; i < 3; i++)
          load(
            i,
            'sequenz_8',
            report['cameras'][i]['frameTimestampsMicroseconds'][7] as int,
          ),
      ];
      final recovery = UncertainHitRecovery();
      final miss = FusedHit(
        const Point(-85.35, -149.326),
        0,
        2,
        forcedDecision: true,
      );
      RecoveredHit? observe(
        List<GrayFrame> frames, [
        List<GrayFrame>? background,
      ]) => recovery
          .observe(miss, before, background ?? empty, frames, calibrations, [
            for (var i = 0; i < 3; i++)
              const FrameDetector().candidates(
                before[i],
                frames[i],
                calibrations[i],
              ),
          ]);
      expect(observe(first), isNull);
      expect(
        observe(first),
        isNull,
        reason: 'A repeated capture cannot confirm a throw',
      );
      final recovered = observe(second);
      expect(recovered, isNotNull);
      expect(BoardGeometry.score(recovered!.hit.point).label, 'T20');
      expect(recovery.metrics['confirmed'], true);
      recovery.reset();
      // Mark all current third-camera pixels as already occupied: its independent
      // evidence disappears, so two alternative shafts alone cannot change MISS.
      expect(observe(first, [empty[0], first[1], empty[2]]), isNull);
      expect(observe(second, [empty[0], second[1], empty[2]]), isNull);
      recovery.reset();
      final untimed = [for (var i = 0; i < 3; i++) load(i, 'sequenz_7')];
      expect(observe(untimed), isNull);
      expect(recovery.metrics['eligible'], false);
    },
  );
}
