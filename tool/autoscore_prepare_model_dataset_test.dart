import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_tournament_manager/features/autoscoring/data/contact_model_sample.dart';
import 'package:dart_tournament_manager/features/autoscoring/domain/board_geometry.dart';
import 'package:dart_tournament_manager/features/autoscoring/domain/lens_distortion.dart';

void main() {
  test(
    'Prepare independently reviewed samples, excluding calibration proposals',
    () {
      const source = String.fromEnvironment(
        'TRAINING_ZIP_ROOT',
        defaultValue: 'build/autoscore_analysis',
      );
      const output = String.fromEnvironment(
        'TRAINING_DATASET_OUTPUT',
        defaultValue: 'build/autoscore_analysis/contact_model_dataset.json',
      );
      final samplesByCapture = <String, Map<String, Object?>>{},
          seen = <String>{};
      final root = Directory(source);
      if (root.existsSync()) {
        for (final file
            in root
                .listSync(recursive: true)
                .whereType<File>()
                .where((f) => f.path.endsWith('.zip'))) {
          final zip = ZipDecoder().decodeBytes(file.readAsBytesSync());
          final reportFile = zip.findFile('bericht.json');
          if (reportFile == null) continue;
          final report =
              jsonDecode(utf8.decode(reportFile.content as List<int>)) as Map;
          final hit = report['hit'] as Map;
          final labels = hit['cameraTrainingLabels'];
          if (labels is! List ||
              hit['xMillimetres'] is! num ||
              hit['yMillimetres'] is! num) {
            continue;
          }
          final reference = [
            for (var i = 1; i <= 3; i++)
              zip.findFile('kamera_${i}_leer.png')?.content ?? <int>[],
          ];
          final referenceGroup = sha256.convert([
            for (final bytes in reference) ...bytes,
          ]).toString();
          for (final label in labels.whereType<Map>()) {
            final camera = label['camera'] as int;
            final key =
                '${report['capturedAtUtc']}:$camera:${label['reviewedAtUtc']}';
            if (!seen.add(key)) continue;
            final metadata = (report['cameras'] as List)
                .where((m) => m['camera'] == camera)
                .firstOrNull;
            final current = zip.findFile('kamera_${camera}_treffer.png');
            final before =
                zip.findFile('kamera_${camera}_vorher_farbe.jpg') ??
                zip.findFile('kamera_${camera}_vorher.png');
            if (metadata == null ||
                metadata['calibration'] is! List ||
                current == null ||
                before == null) {
              continue;
            }
            final cal = BoardCalibration(
              [
                for (final p in metadata['calibration'])
                  BoardPoint(
                    (p['x'] as num).toDouble(),
                    (p['y'] as num).toDouble(),
                  ),
              ],
              lens: LensDistortion.fromJson(
                (metadata['lens'] as Map?) ?? const {},
              ),
            );
            final centre = cal.unproject(
              BoardPoint(
                (hit['xMillimetres'] as num).toDouble(),
                (hit['yMillimetres'] as num).toDouble(),
              ),
            );
            final sample = prepareContactModelSample(
              Uint8List.fromList(current.content as List<int>),
              Uint8List.fromList(before.content as List<int>),
              label,
              {'x': centre.x, 'y': centre.y},
            );
            if (sample != null) {
              final captureKey = '${report['capturedAtUtc']}:$camera';
              final previous = samplesByCapture[captureKey];
              if (previous != null &&
                  (previous['labelReviewId'] as String)
                          .split(':$camera:')
                          .last
                          .compareTo(label['reviewedAtUtc'] as String? ?? '') >=
                      0) {
                continue;
              }
              samplesByCapture[captureKey] = {
                ...sample,
                'eventId': report['capturedAtUtc'],
                'camera': camera,
                'referenceGroup': referenceGroup,
                'sessionId': hit['validationSession'],
                'split': hit['datasetSplit'],
                'sourceZip': file.path,
                'labelReviewId': key,
              };
            }
          }
        }
      }
      final samples = samplesByCapture.values.toList();
      File(output)
        ..parent.createSync(recursive: true)
        ..writeAsStringSync(
          const JsonEncoder.withIndent('  ').convert({
            'schemaVersion': 1,
            'samples': samples,
            'sampleCount': samples.length,
            'status': samples.isEmpty
                ? 'waitingForIndependentImageLabels'
                : 'readyForSplitValidation',
            'modelActivated': false,
            'modelSpec': {
              'input': [2, 32, 32],
              'outputs': ['contactHeatmap', 'occlusion'],
              'trainingScript': 'tool/train_contact_model.py',
            },
          }),
        );
    },
  );
}
