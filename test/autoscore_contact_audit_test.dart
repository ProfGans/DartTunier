import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:archive/archive.dart';
import 'package:dart_tournament_manager/features/autoscoring/data/contact_audit.dart';
import 'package:dart_tournament_manager/features/autoscoring/data/autoscore_diagnostic_export.dart';

void main() {
  test(
    'Contact audit reprojects corrections without changing source pixels',
    () {
      final bytes = Uint8List.fromList(
        img.encodePng(img.Image(width: 160, height: 160)),
      );
      final copy = Uint8List.fromList(bytes);
      final metadata = <String, Object?>{
        'calibration': [
          {'x': .5, 'y': .1},
          {'x': .9, 'y': .5},
          {'x': .5, 'y': .9},
          {'x': .1, 'y': .5},
        ],
        'axis': {'a': 1.0, 'b': 0.0, 'c': 0.0},
      };
      final hit = <String, Object?>{
        'xMillimetres': 0.0,
        'yMillimetres': -100.0,
      };
      final corrected = <String, Object?>{
        'xMillimetres': 5.0,
        'yMillimetres': -100.0,
      };
      final audit = buildContactAudit(bytes, metadata, hit, corrected)!;
      expect(bytes, copy);
      final point = audit.metrics['manualCorrection'] as Map;
      expect(point['inImage'], true);
      expect(point['axisDistanceMillimetres'], 5);
      expect(point['roundTripErrorMillimetres'] as double, lessThan(1e-8));
      expect(audit.metrics['manualPointUsedForRecognition'], false);
      expect(audit.metrics['emptyBoardRingColorSupport'], isNull);
      expect(img.decodePng(audit.overlay), isNotNull);
      final archive = ZipDecoder().decodeBytes(
        const AutoscoreDiagnosticExport().encode(
          AutoscoreEvidence([
            AutoscoreCameraEvidence(bytes, null, null, metadata),
          ], hit),
          '20',
          '20',
          correctionPosition: corrected,
        ),
      );
      expect(archive.findFile('kamera_1_kontaktpruefung.png'), isNotNull);
      expect(archive.findFile('kamera_1_kontaktpruefung.json'), isNotNull);
      expect(buildContactAudit(bytes, {}, hit, corrected), isNull);
    },
  );
}
