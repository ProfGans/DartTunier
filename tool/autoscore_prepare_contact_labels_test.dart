import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_tournament_manager/features/autoscoring/domain/board_geometry.dart';
import 'package:dart_tournament_manager/features/autoscoring/domain/lens_distortion.dart';

int signature(List<int> bytes) {
  var h = 2166136261;
  for (final b in bytes) {
    h = ((h ^ b) * 16777619) & 0xffffffff;
  }
  return h;
}

void main() {
  test(
    'Prepare review-only labels without leaking a board reference between splits',
    () {
      final seen = <String>{}, rows = <Map<String, Object?>>[];
      final groups = <String, String>{};
      for (final file
          in Directory('build/autoscore_analysis')
              .listSync(recursive: true)
              .whereType<File>()
              .where((f) => f.uri.pathSegments.last == 'bericht.json')) {
        final report = jsonDecode(file.readAsStringSync()) as Map;
        final position = report['correctionPosition'];
        if (position is! Map ||
            position['xMillimetres'] is! num ||
            position['yMillimetres'] is! num) {
          continue;
        }
        final id = report['capturedAtUtc'] as String;
        if (!seen.add(id)) continue;
        final cameras = report['cameras'] as List;
        if (cameras.length != 3) continue;
        final folder = file.parent.path;
        final referenceSignatures = <int>[];
        for (var i = 0; i < 3; i++) {
          final empty = File('$folder/kamera_${i + 1}_leer.png');
          referenceSignatures.add(
            empty.existsSync() ? signature(empty.readAsBytesSync()) : 0,
          );
        }
        final group = referenceSignatures.join('-');
        final bucket = signature(utf8.encode(group)) % 10;
        final split = bucket == 0
            ? 'test'
            : bucket == 1
            ? 'validation'
            : 'train';
        expect(groups[group] == null || groups[group] == split, true);
        groups[group] = split;
        for (var i = 0; i < 3; i++) {
          final meta = cameras[i] as Map;
          if (meta['calibration'] is! List) continue;
          final calibration = BoardCalibration(
            [
              for (final p in meta['calibration'])
                BoardPoint(
                  (p['x'] as num).toDouble(),
                  (p['y'] as num).toDouble(),
                ),
            ],
            lens: meta['lens'] is Map
                ? LensDistortion.fromJson(meta['lens'] as Map)
                : const LensDistortion(),
          );
          final expected = BoardPoint(
            (position['xMillimetres'] as num).toDouble(),
            (position['yMillimetres'] as num).toDouble(),
          );
          final projected = calibration.unproject(expected);
          rows.add({
            'eventId': id,
            'referenceGroup': group,
            'split': split,
            'camera': i + 1,
            'imagePath': File(
              '$folder/kamera_${i + 1}_treffer.png',
            ).absolute.path,
            'overlayPath':
                File('$folder/kamera_${i + 1}_kontaktpruefung.png').existsSync()
                ? File(
                    '$folder/kamera_${i + 1}_kontaktpruefung.png',
                  ).absolute.path
                : null,
            'correctedScore': report['corrected'],
            'boardPoint': {'x': expected.x, 'y': expected.y},
            'proposedImagePoint': {'x': projected.x, 'y': projected.y},
            'verifiedImagePoint': null,
            'shaftEndpoints': null,
            'occluded': null,
            'labelSource':
                'manual board correction reprojected through unverified calibration',
            'reviewed': false,
            'trainingEligible': false,
          });
        }
      }
      expect(rows, isNotEmpty);
      File(
        'build/autoscore_analysis/contact_label_review_v1.json',
      ).writeAsStringSync(
        const JsonEncoder.withIndent('  ').convert({
          'schemaVersion': 1,
          'events': seen.length,
          'cameraLabels': rows.length,
          'referenceGroups': groups,
          'activation':
              'No model trained or activated; image labels must be independently checked.',
          'labels': rows,
        }),
      );
    },
  );
}
