import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_tournament_manager/features/autoscoring/domain/board_geometry.dart';
import 'package:dart_tournament_manager/features/autoscoring/domain/frame_detector.dart';
import 'package:dart_tournament_manager/features/autoscoring/domain/lens_distortion.dart';
import 'package:dart_tournament_manager/features/scorer/domain/x01/x01_models.dart';
import '../test/autoscoring_automatic_counting_test.dart' show createController;
import 'package:dart_tournament_manager/features/autoscoring/application/autoscoring_controller.dart';

/// Replay the endpoint branch only. This does not simulate native video capture,
/// missing intermediate frames, exposure synchronization, or USB latency.
class EndpointReplayController extends AutoscoringController {
  @override
  bool get continuousVideo => true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('Replay October correction captures without correction feedback', () {
    final rows = <Map<String, dynamic>>[];
    const endpoints = bool.fromEnvironment('AUTOSCORE_REPLAY_ENDPOINTS');
    final root = Directory(
      const String.fromEnvironment(
        'AUTOSCORE_DIAGNOSTICS_DIR',
        defaultValue: 'build/autoscore_analysis/batch_2026_10_05',
      ),
    );
    for (final directory in root.listSync().whereType<Directory>()) {
      final report =
          jsonDecode(File('${directory.path}/bericht.json').readAsStringSync())
              as Map;
      final accepted = <DartThrowResult>[];
      final seed = createController(accepted);
      final AutoscoringController controller;
      if (endpoints) {
        controller = EndpointReplayController()
          ..automaticCounting = true
          ..running = true
          ..onAutomaticThrow = (result) {
            accepted.add(result);
            return true;
          };
        controller.cameras.addAll(seed.cameras);
        seed.cameras.clear();
        seed.dispose();
      } else {
        controller = seed;
      }
      final frames = <GrayFrame>[];
      final references = <GrayFrame>[];
      final calibrations = <BoardCalibration>[];
      final sourceFiles = <String>[];
      for (var i = 0; i < 3; i++) {
        final camera = report['cameras'][i] as Map;
        final lens = camera['lens'] as Map?;
        final calibration = BoardCalibration(
          [
            for (final p in camera['calibration'])
              Point((p['x'] as num).toDouble(), (p['y'] as num).toDouble()),
          ],
          lens: LensDistortion(
            k1: (lens?['k1'] as num?)?.toDouble() ?? 0,
            aspectRatio: (lens?['aspectRatio'] as num?)?.toDouble() ?? 1,
          ),
        );
        GrayFrame load(String suffix) {
          final alternatives = switch (suffix) {
            'letzter_vorher_detail' => [
              'letzter_vorher_detail',
              'letzter_vorher',
              'vorher_detail',
              'vorher',
            ],
            'sequenz_3_detail' => ['sequenz_3_detail', 'treffer'],
            'leer_detail' => ['leer_detail', 'leer', 'vorher'],
            _ => [suffix],
          };
          for (final alternative in alternatives) {
            final file = File(
              '${directory.path}/kamera_${i + 1}_$alternative.png',
            );
            if (file.existsSync()) {
              sourceFiles.add('kamera_${i + 1}_$alternative.png');
              return decodeCameraFrame(file.readAsBytesSync());
            }
          }
          throw StateError('Fehlendes Kamerabild: ${directory.path}, $suffix');
        }

        final before = load('letzter_vorher_detail');
        final current = load('sequenz_3_detail');
        frames.add(current);
        references.add(before);
        calibrations.add(calibration);
        controller.cameras[i]
          ..calibration = calibration
          ..reference = before
          ..emptyReference = load('leer_detail')
          ..previous = current
          ..stable = 2;
      }
      final watch = Stopwatch()..start();
      for (var n = 0; n < 8; n++) {
        // This tool is a Flutter replay test outside the regular test matrix.
        // ignore: invalid_use_of_visible_for_testing_member
        controller.processFrames([
          for (final f in frames)
            GrayFrame(
              f.width,
              f.height,
              f.pixels,
              detail: f.detail,
              sourceAspectRatio: f.sourceAspectRatio,
            ),
        ]);
      }
      watch.stop();
      double benchmark(bool reuse) {
        final watch = Stopwatch()..start();
        for (var repeat = 0; repeat < 3; repeat++) {
          final detector = FrameDetector(reuseEvidence: reuse);
          for (var i = 0; i < 3; i++) {
            final f = frames[i];
            final fresh = GrayFrame(
              f.width,
              f.height,
              f.pixels,
              detail: f.detail,
            );
            detector.candidates(references[i], fresh, calibrations[i]);
          }
        }
        return watch.elapsedMicroseconds / 3000;
      }

      final localAxes = <DartAxis>[];
      if (controller.lastHit != null) {
        for (var i = 0; i < 3; i++) {
          final camera = controller.cameras[i];
          if (camera.lastAcceptedAxis != null) {
            localAxes.add(
              const FrameDetector().refineAxis(
                camera.lastReference!,
                frames[i],
                camera.calibration!,
                camera.lastAcceptedAxis!,
                nearPoint: controller.lastHit!.point,
              ),
            );
          }
        }
      }
      final localHit = decideAxes(localAxes);
      rows.add({
        'case': directory.uri.pathSegments.where((s) => s.isNotEmpty).last,
        'endpointBranchEnabled': endpoints,
        'repeatedStillFrameReplay': true,
        'sourceFiles': sourceFiles,
        'capturedAtUtc': report['capturedAtUtc'],
        'recorded': report['detected'],
        'corrected': report['corrected'],
        'replayed': accepted.map((a) => a.label).toList(),
        'milliseconds': watch.elapsedMicroseconds / 1000,
        'freshCaptureCandidatesMilliseconds': {
          'uncached': benchmark(false),
          'reused': benchmark(true),
        },
        'localHit': localHit == null
            ? null
            : [localHit.point.x, localHit.point.y, localHit.residual],
        'point': controller.lastHit == null
            ? null
            : [controller.lastHit!.point.x, controller.lastHit!.point.y],
        'tipContactConfirmed': controller.tipContactConfirmed,
        'status': controller.status,
        'referenceChangeFractions': [
          for (var i = 0; i < 3; i++)
            const FrameDetector().changedFraction(references[i], frames[i]),
        ],
        'tips': [
          for (final tip in controller.tipObservations)
            tip == null
                ? null
                : {
                    'x': tip.board.x,
                    'y': tip.board.y,
                    'confidence': tip.confidence,
                  },
        ],
        'spatialContact': controller.spatialContact?.toJson(),
      });
      controller.dispose();
    }
    File(
      const String.fromEnvironment(
        'AUTOSCORE_REPLAY_OUTPUT',
        defaultValue: 'build/autoscore_analysis/october_replay.json',
      ),
    ).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(rows));
    expect(rows, isNotEmpty);
  });
}
