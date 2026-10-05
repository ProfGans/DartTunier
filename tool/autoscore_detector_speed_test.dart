import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_tournament_manager/features/autoscoring/domain/board_geometry.dart';
import 'package:dart_tournament_manager/features/autoscoring/domain/frame_detector.dart';
import 'package:dart_tournament_manager/features/autoscoring/domain/lens_distortion.dart';
import 'support/legacy_frame_detector.dart';

void main() {
  test(
    'Fresh detector batches preserve all candidates and record paired timings',
    () {
      final samples = <(GrayFrame, GrayFrame, BoardCalibration)>[];
      for (final dir in Directory(
        'build/autoscore_analysis/user_old_25',
      ).listSync().whereType<Directory>()) {
        final report =
            jsonDecode(File('${dir.path}/bericht.json').readAsStringSync())
                as Map;
        for (var i = 0; i < 3; i++) {
          GrayFrame load(List<String> names) {
            for (final name in names) {
              final file = File('${dir.path}/kamera_${i + 1}_$name.png');
              if (file.existsSync()) {
                return decodeCameraFrame(file.readAsBytesSync());
              }
            }
            throw StateError('Missing image');
          }

          final meta = report['cameras'][i] as Map;
          samples.add((
            load(['letzter_vorher', 'vorher']),
            load(['treffer']),
            BoardCalibration(
              [
                for (final p in meta['calibration'])
                  Point((p['x'] as num).toDouble(), (p['y'] as num).toDouble()),
              ],
              lens: LensDistortion.fromJson(
                (meta['lens'] as Map?) ?? const {'k1': 0, 'aspectRatio': 1},
              ),
            ),
          ));
        }
      }
      for (final id in ['5', '97', '126']) {
        final root = 'build/autoscore_analysis/new_2026_10_05/case_$id';
        final report =
            jsonDecode(File('$root/bericht.json').readAsStringSync()) as Map;
        for (var i = 0; i < 3; i++) {
          final meta = report['cameras'][i] as Map;
          samples.add((
            decodeCameraFrame(
              File(
                '$root/kamera_${i + 1}_letzter_vorher_detail.png',
              ).readAsBytesSync(),
            ),
            decodeCameraFrame(
              File(
                '$root/kamera_${i + 1}_sequenz_7_detail.png',
              ).readAsBytesSync(),
            ),
            BoardCalibration([
              for (final p in meta['calibration'])
                Point((p['x'] as num).toDouble(), (p['y'] as num).toDouble()),
            ], lens: LensDistortion.fromJson(meta['lens'] as Map)),
          ));
        }
      }
      for (final (before, after, cal) in samples) {
        final old = const LegacyFrameDetector(
          reuseEvidence: false,
        ).candidates(before, after, cal);
        final fresh = const FrameDetector(
          reuseEvidence: false,
        ).candidates(before, after, cal);
        expect(fresh.length, old.length);
        for (var i = 0; i < old.length; i++) {
          expect(
            [
              fresh[i].a,
              fresh[i].b,
              fresh[i].c,
              fresh[i].confidence,
              fresh[i].outerRimOnly,
            ],
            [
              old[i].a,
              old[i].b,
              old[i].c,
              old[i].confidence,
              old[i].outerRimOnly,
            ],
          );
        }
      }
      double measure(bool legacy) {
        final timer = Stopwatch()..start();
        for (final (before, after, cal) in samples) {
          // Each fresh camera capture shares evidence between axis and alternatives.
          final frame = GrayFrame(
            after.width,
            after.height,
            after.pixels,
            detail: after.detail,
          );
          if (legacy) {
            const detector = LegacyFrameDetector();
            final axis = detector.axis(before, frame, cal);
            detector.candidates(before, frame, cal, primary: axis);
          } else {
            const detector = FrameDetector();
            final axis = detector.axis(before, frame, cal);
            detector.candidates(before, frame, cal, primary: axis);
          }
        }
        return timer.elapsedMicroseconds / 1000;
      }

      measure(true);
      measure(false);
      final rows = <Map<String, Object>>[];
      for (var i = 0; i < 5; i++) {
        late double old, fresh;
        if (i.isEven) {
          old = measure(true);
          fresh = measure(false);
        } else {
          fresh = measure(false);
          old = measure(true);
        }
        rows.add({
          'legacyMilliseconds': old,
          'currentMilliseconds': fresh,
          'reductionPercent': (old - fresh) / old * 100,
        });
      }
      File(
        'build/autoscore_analysis/detector_speed_timings.json',
      ).writeAsStringSync(
        const JsonEncoder.withIndent(
          '  ',
        ).convert({'cameraSamples': samples.length, 'runs': rows}),
      );
    },
  );
}
