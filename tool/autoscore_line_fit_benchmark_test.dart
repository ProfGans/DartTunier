import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_tournament_manager/features/autoscoring/domain/board_geometry.dart';
import 'package:dart_tournament_manager/features/autoscoring/domain/shaft_line_fit.dart';
import 'support/legacy_shaft_line_fit.dart';

void main() {
  test(
    'Line-fit optimization keeps results and records paired CPU timings',
    () {
      final calibration = BoardCalibration(const [
        Point(.5, .1),
        Point(.9, .5),
        Point(.5, .9),
        Point(.1, .5),
      ]);
      final random = Random(1701);
      final samples = [
        for (var n = 0; n < 8; n++)
          [
            for (var i = 0; i < 600; i++)
              i < 450
                  ? Point(
                      .1 + i / 750,
                      .2 + i / 1300 + random.nextDouble() / 800,
                    )
                  : Point(random.nextDouble(), random.nextDouble()),
          ],
      ];
      for (final points in samples) {
        final old = legacyFitShaftLine(points, calibration, 1280, 720);
        final fresh = fitShaftLine(points, calibration, 1280, 720);
        expect(fresh != null, old != null);
        if (old != null) {
          expect(fresh!.a, old.a);
          expect(fresh.b, old.b);
          expect(fresh.c, old.c);
          expect(fresh.confidence, old.confidence);
        }
      }
      double measure(bool legacy) {
        final watch = Stopwatch()..start();
        for (var repeat = 0; repeat < 10; repeat++) {
          for (final points in samples) {
            if (legacy) {
              legacyFitShaftLine(points, calibration, 1280, 720);
            } else {
              fitShaftLine(points, calibration, 1280, 720);
            }
          }
        }
        return watch.elapsedMicroseconds / 1000;
      }

      final runs = [
        for (var i = 0; i < 3; i++)
          {
            'legacyMilliseconds': measure(true),
            'optimizedMilliseconds': measure(false),
          },
      ];
      File(
        'build/autoscore_analysis/line_fit_timings.json',
      ).writeAsStringSync(jsonEncode(runs));
    },
  );
}
