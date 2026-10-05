import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:dart_tournament_manager/features/autoscoring/data/automatic_calibration_service.dart';
import 'package:dart_tournament_manager/features/autoscoring/domain/board_geometry.dart';
import 'package:dart_tournament_manager/features/scorer/domain/x01/x01_rules.dart';
import 'package:dart_tournament_manager/features/autoscoring/application/autoscoring_controller.dart';
import 'package:dart_tournament_manager/features/autoscoring/application/camera_selection.dart';

/// Exercises the actual native Windows OCR + Dart geometry without any camera.
/// flutter run -d windows --profile -t tool/autoscoring_ocr_probe.dart
///   --dart-define=OCR_REPORT_PATH=absolute_report_path
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const reportPath = String.fromEnvironment('OCR_REPORT_PATH');
  if (reportPath.isEmpty) exit(2);
  runApp(
    const MaterialApp(
      home: Scaffold(
        body: Center(
          child: Text('Automatische Board-Kalibrierung wird geprüft …'),
        ),
      ),
    ),
  );
  var code = 1;
  final report = <String, dynamic>{};
  try {
    const captureCameras = bool.fromEnvironment('OCR_CAPTURE_CAMERAS');
    if (captureCameras) {
      final controller = AutoscoringController();
      await controller.discover();
      await controller.connect(preferredAutoscoreCameras(controller.available));
      final cameras = <Map<String, dynamic>>[];
      for (var i = 0; i < controller.cameras.length; i++) {
        final camera = controller.cameras[i];
        final bytes = camera.snapshot;
        if (bytes != null) {
          final file = File(
            '${File(reportPath).parent.path}/camera_${i + 1}.jpg',
          );
          await file.parent.create(recursive: true);
          await file.writeAsBytes(bytes);
        }
        cameras.add({
          'camera': i + 1,
          'success': camera.calibration != null,
          'message': camera.calibrationMessage,
        });
      }
      final file = File(reportPath);
      await file.parent.create(recursive: true);
      await file.writeAsString(
        const JsonEncoder.withIndent(
          '  ',
        ).convert({'status': controller.status, 'cameras': cameras}),
      );
      controller.dispose();
      exit(0);
    }
    const fixtureDirectory = String.fromEnvironment('OCR_FIXTURE_DIRECTORY');
    if (fixtureDirectory.isNotEmpty) {
      final results = <Map<String, dynamic>>[];
      final calibrations = <BoardCalibration?>[];
      for (var i = 1; i <= 3; i++) {
        final diagnostic = <String, dynamic>{};
        try {
          final result =
              await WindowsAutomaticCalibrationService(
                useReferenceCache: false,
                onWords: (rotation, words) =>
                    diagnostic['words_$rotation'] = words,
                onNumbers: (numbers) => diagnostic['numbers'] = [
                  for (final n in numbers)
                    {'value': n.value, 'x': n.position.x, 'y': n.position.y},
                ],
              ).calibrate(
                await (File('$fixtureDirectory/original_$i.jpg').existsSync()
                        ? File('$fixtureDirectory/original_$i.jpg')
                        : File('$fixtureDirectory/camera_$i.png'))
                    .readAsBytes(),
              );
          results.add({
            'camera': i,
            'success': true,
            'numbers': result.numberCount,
            'diagnostic': diagnostic,
            'calibration': [
              for (final p in result.calibration.points) {'x': p.x, 'y': p.y},
            ],
          });
          calibrations.add(result.calibration);
        } catch (e) {
          results.add({
            'camera': i,
            'success': false,
            'error': '$e',
            'diagnostic': diagnostic,
          });
          calibrations.add(null);
        }
      }
      for (var i = 1; i <= 3; i++) {
        if (results[i - 1]['success'] == true) continue;
        try {
          final file = File('$fixtureDirectory/original_$i.jpg').existsSync()
              ? File('$fixtureDirectory/original_$i.jpg')
              : File('$fixtureDirectory/camera_$i.png');
          final reference = calibrations.indexWhere((c) => c != null);
          if (reference < 0) continue;
          final referenceFile =
              File(
                '$fixtureDirectory/original_${reference + 1}.jpg',
              ).existsSync()
              ? File('$fixtureDirectory/original_${reference + 1}.jpg')
              : File('$fixtureDirectory/camera_${reference + 1}.png');
          final result =
              await const WindowsAutomaticCalibrationService(
                useReferenceCache: false,
              ).calibrateUsingReference(
                await file.readAsBytes(),
                await referenceFile.readAsBytes(),
                calibrations[reference]!,
              );
          results[i - 1] = {
            'camera': i,
            'success': true,
            'numbers': result.numberCount,
            'method': 'automatic_reference',
            'calibration': [
              for (final p in result.calibration.points) {'x': p.x, 'y': p.y},
            ],
          };
        } catch (_) {}
      }
      final success = results.every((r) => r['success'] == true);
      final file = File(reportPath);
      await file.parent.create(recursive: true);
      await file.writeAsString(
        const JsonEncoder.withIndent(
          '  ',
        ).convert({'success': success, 'cameras': results}),
      );
      exit(success ? 0 : 1);
    }
    final picture = img.Image(width: 768, height: 768);
    img.fill(picture, color: img.ColorRgb8(20, 20, 20));
    for (final p in picture) {
      final q = Point((p.x - 384) / 260, (p.y - 384) / 260), r = q.magnitude;
      if (r > 1) continue;
      final sector =
          ((atan2(q.x, -q.y) + 2 * pi + pi / 20) % (2 * pi) / (pi / 10))
              .floor();
      if (r < 6.35 / 170) {
        p.setRgb(190, 25, 30);
      } else if (r < 15.9 / 170) {
        p.setRgb(20, 135, 60);
      } else if (r > 162 / 170 || (r > 99 / 170 && r < 107 / 170)) {
        if (sector.isEven) {
          p.setRgb(190, 25, 30);
        } else {
          p.setRgb(20, 135, 60);
        }
      } else {
        final shade = sector.isEven ? 30 : 200;
        p.setRgb(shade, shade, shade);
      }
    }
    for (var i = 0; i < 20; i++) {
      final text = '${X01Rules.wheel[i]}', angle = i * pi / 10;
      img.drawString(
        picture,
        text,
        font: img.arial24,
        x: (384 + sin(angle) * 307 - text.length * 7).round(),
        y: (384 - cos(angle) * 307 - 12).round(),
        color: img.ColorRgb8(235, 235, 235),
      );
    }
    final bytes = img.encodePng(picture);
    final result = await WindowsAutomaticCalibrationService(
      onWords: (rotation, words) {
        (report.putIfAbsent('ocr_passes', () => <Map<String, dynamic>>[])
                as List)
            .add({'rotation': rotation, 'words': words});
      },
      onNumbers: (numbers) {
        report['recognized'] = [
          for (final n in numbers)
            {
              'number': n.value,
              'x': n.position.x,
              'y': n.position.y,
              'angle': atan2(n.position.x, -n.position.y),
            },
        ];
      },
    ).calibrate(bytes);
    final score = BoardGeometry.score(
      result.calibration.project(
        const Point(384 / 767, (384 - 103 / 170 * 260) / 767),
      ),
    );
    report.addAll({
      'success': score.label == 'T20',
      'numbers': result.numberCount,
      'score': score.label,
      'points': [
        for (final p in result.calibration.points) [p.x, p.y],
      ],
    });
    code = score.label == 'T20' ? 0 : 1;
  } catch (e, stack) {
    report.addAll({'success': false, 'error': '$e', 'stack': '$stack'});
  }
  final file = File(reportPath);
  await file.parent.create(recursive: true);
  await file.writeAsString(const JsonEncoder.withIndent('  ').convert(report));
  exit(code);
}
