import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_tournament_manager/features/autoscoring/domain/board_geometry.dart';
import 'package:dart_tournament_manager/features/autoscoring/domain/frame_detector.dart';
import 'package:dart_tournament_manager/features/autoscoring/domain/lens_distortion.dart';
import 'package:dart_tournament_manager/features/autoscoring/domain/dart_tip_detection.dart';
import 'package:dart_tournament_manager/features/scorer/domain/x01/x01_models.dart';
import '../test/autoscoring_automatic_counting_test.dart' show createController;
import 'autoscore_diagnostics_replay_test.dart' show EndpointReplayController;

class ConfigurableVideoReplayController extends EndpointReplayController {
  @override
  bool get continuousVideo =>
      const bool.fromEnvironment('VIDEO_REPLAY_ENDPOINTS', defaultValue: true);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('Replay actual saved video sequences without correction feedback', () {
    final rows = <Map<String, Object?>>[];
    const ids = String.fromEnvironment(
      'VIDEO_REPLAY_CASES',
      defaultValue: '5,97,126',
    );
    for (final id in ids.split(',')) {
      const base = String.fromEnvironment(
        'VIDEO_REPLAY_ROOT',
        defaultValue: 'build/autoscore_analysis/new_2026_10_05',
      );
      final root = '$base/case_$id';
      final report =
          jsonDecode(File('$root/bericht.json').readAsStringSync()) as Map;
      final accepted = <DartThrowResult>[];
      final seed = createController([]);
      final c = ConfigurableVideoReplayController()
        ..running = true
        ..automaticCounting = true
        ..onAutomaticThrow = (result) {
          accepted.add(result);
          return true;
        };
      c.cameras.addAll(seed.cameras);
      seed.cameras.clear();
      seed.dispose();
      GrayFrame load(int camera, String name, {int? time, int? sequence}) {
        final low = decodeCameraFrame(
          File('$root/kamera_${camera + 1}_$name.png').readAsBytesSync(),
        );
        final detailFile = File(
          '$root/kamera_${camera + 1}_${name}_detail.png',
        );
        final decoded = detailFile.existsSync()
            ? decodeCameraFrame(detailFile.readAsBytesSync())
            : null;
        return GrayFrame(
          low.width,
          low.height,
          low.pixels,
          detail: decoded?.detail ?? decoded,
          colorImage:
              File('$root/kamera_${camera + 1}_${name}_farbe.jpg').existsSync()
              ? File(
                  '$root/kamera_${camera + 1}_${name}_farbe.jpg',
                ).readAsBytesSync()
              : null,
          sourceAspectRatio: low.width / low.height,
          timestampUs: time,
          sequence: sequence,
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
      final states = <Map<String, Object?>>[];
      for (var n = 0; n < 12; n++) {
        final frames = [
          for (var i = 0; i < 3; i++)
            load(
              i,
              n < 8 ? 'sequenz_${n + 1}' : 'nachher_${n - 7}',
              time: n < 8
                  ? report['cameras'][i]['frameTimestampsMicroseconds'][n]
                        as int?
                  : report['cameras'][i]['postFrames'][n -
                            8]['timestampMicroseconds']
                        as int?,
              sequence: n,
            ),
        ];
        final referenceChanges = [
          for (var i = 0; i < 3; i++)
            const FrameDetector().changedFraction(
              c.cameras[i].reference!,
              frames[i],
              threshold: 17,
            ),
        ];
        final motionChanges = [
          for (var i = 0; i < 3; i++)
            const FrameDetector().changedFraction(
              c.cameras[i].previous!,
              frames[i],
              threshold: 17,
            ),
        ];
        // ignore: invalid_use_of_visible_for_testing_member
        c.processFrames(frames);
        final probes = <Map<String, Object?>>[];
        if (id == '126' && n == 6) {
          for (final a in c.cameras[0].axisCandidates) {
            for (final b in c.cameras[2].axisCandidates) {
              final hit = decideAxes([a, b]);
              if (hit == null || hit.point.magnitude > 170) continue;
              final tip = refineTipContact(
                hit,
                c.cameras.map((cam) => cam.reference!).toList(),
                frames,
                c.cameras.map((cam) => cam.calibration!).toList(),
                [a, null, b],
              );
              probes.add({
                'point': [hit.point.x, hit.point.y],
                'label': BoardGeometry.score(hit.point).label,
                'confidence': [a.confidence, b.confidence],
                'confirmed': tip.confirmed,
                'nearbyChanges': [
                  for (var i = 0; i < 3; i++)
                    (() {
                      final pixels = const FrameDetector()
                          .changeSamples(
                            c.cameras[i].reference!,
                            frames[i],
                            c.cameras[i].calibration!,
                          )
                          .map((p) => c.cameras[i].calibration!.project(p))
                          .toList();
                      return {
                        'within6mm': pixels
                            .where((p) => p.distanceTo(hit.point) < 6)
                            .length,
                        'nearestMm': pixels.isEmpty
                            ? null
                            : pixels
                                  .map((p) => p.distanceTo(hit.point))
                                  .reduce(min),
                      };
                    })(),
                ],
                'tips': [
                  for (final obs in tip.observations)
                    obs == null ? null : [obs.board.x, obs.board.y],
                ],
              });
            }
          }
        }
        states.add({
          'frame': n,
          'probes': probes,
          'status': c.status,
          'decisionReason': c.decisionReason,
          'decisionMetrics': c.decisionMetrics,
          'processingMilliseconds': c.processingMilliseconds,
          'localBoundary': c.localBoundaryMetrics,
          'ringContact': c.localRingMetrics,
          'contactComparison': c.contactComparisonMetrics,
          'contactComparisonMilliseconds': [
            for (final stage in c.diagnosticTimeline.last['stages'] as List)
              if (stage['phase'] == 'contactCandidateComparison')
                stage['milliseconds'],
          ],
          'localBoundaryMilliseconds': [
            for (final stage in c.diagnosticTimeline.last['stages'] as List)
              if (stage['phase'] == 'localSegmentBoundary')
                stage['milliseconds'],
          ],
          'recovery': c.recoveryMetrics,
          'axisIntersection': (() {
            final hit = fuseAxes(
              c.cameras
                  .map((cam) => cam.detectedAxis)
                  .whereType<DartAxis>()
                  .toList(),
            );
            return hit == null
                ? null
                : {
                    'label': BoardGeometry.score(hit.point).label,
                    'x': hit.point.x,
                    'y': hit.point.y,
                    'views': hit.views,
                    'residual': hit.residual,
                  };
          })(),
          'counted': accepted.map((a) => a.label).toList(),
          'point': c.pending == null
              ? null
              : [c.pending!.point.x, c.pending!.point.y],
          'tips': [
            for (final t in c.tipObservations)
              t == null
                  ? null
                  : {
                      'x': t.board.x,
                      'y': t.board.y,
                      'confidence': t.confidence,
                    },
          ],
          'referenceChanges': referenceChanges,
          'motionChanges': motionChanges,
          'stableSamples': c.cameras.map((cam) => cam.stable).toList(),
          'tipReason': c.tipDecisionReason,
          'axes': [
            for (final camera in c.cameras)
              [
                for (final a in camera.axisCandidates)
                  {
                    'a': a.a,
                    'b': a.b,
                    'c': a.c,
                    'confidence': a.confidence,
                    'rim': a.outerRimOnly,
                  },
              ],
          ],
          'primaryAxes': [
            for (final camera in c.cameras)
              camera.detectedAxis == null
                  ? null
                  : {
                      'a': camera.detectedAxis!.a,
                      'b': camera.detectedAxis!.b,
                      'c': camera.detectedAxis!.c,
                      'confidence': camera.detectedAxis!.confidence,
                    },
          ],
        });
      }
      rows.add({
        'case': id,
        'recorded': report['detected'],
        'expected': report['corrected'],
        'replayed': accepted.map((a) => a.label).toList(),
        'states': states,
      });
      c.dispose();
    }
    File(
      const String.fromEnvironment(
        'VIDEO_REPLAY_OUTPUT',
        defaultValue: 'build/autoscore_analysis/new_video_baseline.json',
      ),
    ).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(rows));
    expect(rows.length, ids.split(',').length);
  });
}
