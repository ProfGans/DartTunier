import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:dart_tournament_manager/features/autoscoring/domain/frame_detector.dart';
import 'package:dart_tournament_manager/features/autoscoring/data/diagnostic_capture_metrics.dart';
import 'package:dart_tournament_manager/features/autoscoring/data/autoscore_diagnostic_export.dart';
import 'package:dart_tournament_manager/features/autoscoring/application/recognition_diagnostic_trace.dart';

void main() {
  test(
    'Quality reports exposure clipping and texture without inventing FPS',
    () {
      GrayFrame frame(int value) =>
          GrayFrame(10, 10, Uint8List(100)..fillRange(0, 100, value));
      final black = diagnosticImageQuality(frame(0));
      expect(black['darkClippingFraction'], 1);
      expect(black['laplacianVariance'], 0);
      expect(diagnosticImageQuality(frame(255))['brightClippingFraction'], 1);
      final cadence = diagnosticCaptureCadence(
        [100, 100, 90, 500],
        [1, 2, 5, 6],
      );
      expect(cadence['repeatedTimestamps'], 1);
      expect(cadence['nonmonotonicTimestamps'], 1);
      expect(cadence['sequenceGaps'], 2);
      expect(cadence['maximumHostIntervalMilliseconds'], .41);
    },
  );
  test('Timeline is bounded and snapshots cannot change after capture', () {
    final trace = RecognitionDiagnosticTrace();
    final state = <String, Object?>{
      'axes': [1, 2],
    };
    trace.begin([], 0);
    trace.checkpoint('fusion', state);
    final snapshot = trace.snapshot();
    (state['axes'] as List).add(3);
    trace.checkpoint('accepted', {'score': '20'});
    expect(((snapshot[0]['stages'] as List)[0]['state'] as Map)['axes'], [
      1,
      2,
    ]);
    expect((snapshot[0]['stages'] as List).length, 1);
    for (var i = 0; i < 20; i++) {
      trace.begin([], i);
    }
    expect(trace.snapshot().length, 12);
    trace.clear();
    expect(trace.snapshot(), isEmpty);
  });
  test('Export preserves exact selected frame even without selected RGB', () {
    GrayFrame frame(int value, int time) => GrayFrame(
      10,
      10,
      Uint8List(100)..fillRange(0, 100, value),
      timestampUs: time,
    );
    final latest = img.Image(width: 10, height: 10);
    img.fill(latest, color: img.ColorRgb8(200, 200, 200));
    final camera = AutoscoreCameraEvidence(
      Uint8List.fromList(img.encodePng(latest)),
      null,
      null,
      {
        'camera': 1,
        'frameSequences': [1, 2],
        'calibration': [
          {'x': .5, 'y': .1},
          {'x': .9, 'y': .5},
          {'x': .5, 'y': .9},
          {'x': .1, 'y': .5},
        ],
      },
      frames: [frame(50, 100), frame(200, 200)],
      frameTimes: [100, 200],
    );
    final archive = ZipDecoder().decodeBytes(
      const AutoscoreDiagnosticExport().encode(
        AutoscoreEvidence(
          [camera],
          {
            'decisionSelectedFrame': 0,
            'decisionFrames': [
              {
                'captureTimestampsMicroseconds': [100],
              },
            ],
            'decisionReason': 'independentThreeCameraSupport',
          },
        ),
        '1',
        '20',
      ),
    );
    final selected = img.decodePng(
      Uint8List.fromList(
        archive.findFile('kamera_1_entscheidung.png')!.content as List<int>,
      ),
    )!;
    expect(selected.getPixel(0, 0).r, 50);
    final original = img.decodePng(
      Uint8List.fromList(
        archive.findFile('kamera_1_treffer.png')!.content as List<int>,
      ),
    )!;
    expect(original.getPixel(0, 0).r, 200);
    final summary = jsonDecode(
      utf8.decode(
        archive.findFile('diagnose_zusammenfassung.json')!.content as List<int>,
      ),
    );
    expect(summary['cameras'][0]['selectedSequenceIndex'], 0);
    final audit = jsonDecode(
      utf8.decode(
        archive.findFile('kamera_1_kontaktpruefung.json')!.content as List<int>,
      ),
    );
    expect(audit['imageSource'], 'selectedDecisionFrame');
    expect(archive.findFile('DIAGNOSE_UEBERSICHT.txt'), isNotNull);
  });
}
