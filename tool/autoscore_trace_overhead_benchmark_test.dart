import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_tournament_manager/features/autoscoring/application/recognition_diagnostic_trace.dart';
import 'package:dart_tournament_manager/features/autoscoring/domain/frame_detector.dart';

void main() {
  test(
    'Measure actual diagnostic trace payload independent of image analysis',
    () {
      final report =
          jsonDecode(
                File(
                  'test/fixtures/autoscoring/new_video/case_94/bericht.json',
                ).readAsStringSync(),
              )
              as Map;
      final entries = (report['hit'] as Map)['recognitionTimeline'] as List;
      final trace = RecognitionDiagnosticTrace();
      final frames = [
        for (var i = 0; i < 3; i++) GrayFrame(1, 1, Uint8List(1)),
      ];
      void record() {
        for (final entry in entries.cast<Map>()) {
          trace.begin(frames, 0);
          for (final stage in (entry['stages'] as List).cast<Map>()) {
            trace.checkpoint(
              stage['phase'] as String,
              (stage['state'] as Map).cast<String, Object?>(),
            );
          }
        }
        expect(trace.snapshot().length, entries.length);
      }

      record();
      final results = <double>[];
      for (var n = 0; n < 10; n++) {
        final watch = Stopwatch()..start();
        record();
        watch.stop();
        results.add(watch.elapsedMicroseconds / 1000 / entries.length);
      }
      File(
        'build/autoscore_analysis/trace_overhead_benchmark.json',
      ).writeAsStringSync(
        jsonEncode({
          'millisecondsPerThreeCameraObservation': results,
          'includesFullTimelineSnapshot': true,
          'excludesImageEncodingAndRecognition': true,
          'liveUsbLatencyMeasured': false,
        }),
      );
    },
  );
}
