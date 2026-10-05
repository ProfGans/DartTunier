import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:image/image.dart' as img;
import 'package:dart_tournament_manager/features/autoscoring/application/autoscoring_controller.dart';
import 'package:dart_tournament_manager/features/autoscoring/application/capture_autoscore_evidence.dart';
import 'package:dart_tournament_manager/features/autoscoring/data/autoscore_diagnostic_export.dart';
import 'package:dart_tournament_manager/features/autoscoring/domain/frame_detector.dart';
import 'package:dart_tournament_manager/features/autoscoring/domain/board_geometry.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('Diagnostics preserve true colors and timed post-decision sequence', () {
    final image = img.Image(width: 8, height: 8);
    img.fill(image, color: img.ColorRgb8(240, 30, 20));
    final color = img.encodePng(image);
    final frame = GrayFrame(
      8,
      8,
      Uint8List(64),
      colorImage: color,
      timestampUs: 123456,
      sequence: 9,
    );
    final camera = AutoscoreCameraEvidence(
      color,
      frame,
      frame,
      {},
      beforeColor: color,
      emptyColor: color,
      frames: [frame],
      frameColors: [color],
      postFrames: [frame],
    );
    final archive = ZipDecoder().decodeBytes(
      const AutoscoreDiagnosticExport().encode(
        AutoscoreEvidence([camera], {}),
        '20',
        'T20',
      ),
    );
    for (final name in [
      'kamera_1_vorher_farbe.jpg',
      'kamera_1_leer_farbe.jpg',
      'kamera_1_sequenz_1_farbe.jpg',
      'kamera_1_nachher_1_farbe.jpg',
    ]) {
      final pixel = img
          .decodeJpg(
            Uint8List.fromList(archive.findFile(name)!.content as List<int>),
          )!
          .getPixel(0, 0);
      expect(pixel.r, greaterThan(220));
      expect(pixel.g, lessThan(50));
    }
    expect(archive.findFile('kamera_1_nachher_1.png'), isNotNull);
    expect(archive.findFile('kamera_1_ablauf.gif'), isNotNull);
    expect(
      img.decodeGif(
        Uint8List.fromList(
          archive.findFile('kamera_1_ablauf.gif')!.content as List<int>,
        ),
      ),
      isNotNull,
    );
    final report = jsonDecode(
      utf8.decode(archive.findFile('bericht.json')!.content as List<int>),
    );
    expect(
      report['cameras'][0]['postFrames'][0]['timestampMicroseconds'],
      123456,
    );
    expect(report['cameras'][0]['postFrames'][0]['sequence'], 9);
  });
  test('Manual override without camera images still exports a diagnosis', () {
    final c = AutoscoringController();
    final evidence = captureAutoscoreEvidence(
      c,
      missed: true,
      allowPartial: true,
    )!;
    final bytes = const AutoscoreDiagnosticExport().encode(
      evidence,
      'Nicht erkannt',
      'T20',
      correctionPosition: {
        'xMillimetres': 0.0,
        'yMillimetres': -103.0,
        'source': 'manualMissingPoint',
      },
    );
    final zip = ZipDecoder().decodeBytes(bytes);
    final report =
        jsonDecode(
              utf8.decode(zip.findFile('bericht.json')!.content as List<int>),
            )
            as Map;
    expect(report['hit']['missingCameraImages'], 3);
    expect(report['correctionPosition']['yMillimetres'], -103.0);
    expect(report['detected'], 'Nicht erkannt');
    c.dispose();
  });
  test(
    'Removal report preserves event state without marking a scoring error',
    () {
      final evidence = AutoscoreEvidence([], {
        'eventType': 'manualRemoval',
        'statusBeforeReset': 'Pfeile herausziehen',
        'waitingForEmpty': true,
        'throws': [
          {'label': 'T20', 'points': 60},
        ],
      });
      final archive = ZipDecoder().decodeBytes(
        const AutoscoreDiagnosticExport().encode(
          evidence,
          'Blockiert',
          'Board leer',
        ),
      );
      final report = jsonDecode(
        utf8.decode(archive.findFile('bericht.json')!.content as List<int>),
      );
      expect(report['schemaVersion'], 8);
      expect(report['correctDetection'], isNull);
      expect(report['hit']['eventType'], 'manualRemoval');
      expect(report['hit']['throws'].first['points'], 60);
      expect(
        utf8.decode(archive.findFile('LESEN.txt')!.content as List<int>),
        contains('vor dem Reset'),
      );
    },
  );
  test(
    'Correction ZIP keeps original three-camera observations and geometry after board removal',
    () async {
      final c = AutoscoringController();
      addTearDown(c.dispose);
      for (var i = 0; i < 3; i++) {
        final image = img.Image(width: 12, height: 8);
        img.fill(image, color: img.ColorRgb8(40 + i * 40, 20, 10));
        c.cameras.add(
          AutoscoreCamera(
              const CameraDescription(
                name: 'USB',
                lensDirection: CameraLensDirection.external,
                sensorOrientation: 0,
              ),
              i,
              1.5,
            )
            ..snapshot = img.encodePng(image)
            ..lastReference = GrayFrame(
              2,
              2,
              Uint8List.fromList([0, 20, 40, 60]),
            )
            ..emptyReference = GrayFrame(2, 2, Uint8List(4))
            ..lastAcceptedAxis = DartAxis(
              const Point(0, 0),
              const Point(0, 100),
              confidence: .8,
            )
            ..calibration = BoardCalibration(const [
              Point(.5, .1),
              Point(.9, .5),
              Point(.5, .9),
              Point(.1, .5),
            ]),
        );
      }
      c.lastHit = const FusedHit(Point(0, -103), 2, 3);
      final evidence = captureAutoscoreEvidence(c)!;
      for (final camera in c.cameras) {
        camera.snapshot!.fillRange(0, camera.snapshot!.length, 0);
      }
      final directory = Directory.systemTemp.createTempSync(
        'autoscore_evidence_',
      );
      addTearDown(() => directory.deleteSync(recursive: true));
      final path = await const AutoscoreDiagnosticExport().save(
        evidence,
        'T20',
        'S20',
        directory: directory,
        correctionPosition: {
          'xMillimetres': 12.0,
          'yMillimetres': -120.0,
          'source': 'flatBoard',
        },
      );
      final archive = ZipDecoder().decodeBytes(await File(path).readAsBytes());
      final report =
          jsonDecode(
                utf8.decode(
                  archive.findFile('bericht.json')!.content as List<int>,
                ),
              )
              as Map<String, dynamic>;
      expect(report['schemaVersion'], 8);
      expect(report['correctionPosition']['xMillimetres'], 12.0);
      expect(report['detected'], 'T20');
      expect(report['corrected'], 'S20');
      expect(report['correctDetection'], isFalse);
      expect(report['hit']['yMillimetres'], -103);
      final missingArchive = ZipDecoder().decodeBytes(
        const AutoscoreDiagnosticExport().encode(
          AutoscoreEvidence(evidence.cameras, {'manualMissingReport': true}),
          'Nicht erkannt',
          'T20',
          correctionPosition: {
            'xMillimetres': 0.0,
            'yMillimetres': -103.0,
            'source': 'manualMissingPoint',
          },
        ),
      );
      final missingReport = jsonDecode(
        utf8.decode(
          missingArchive.findFile('bericht.json')!.content as List<int>,
        ),
      );
      expect(missingReport['detected'], 'Nicht erkannt');
      expect(missingReport['hit']['xMillimetres'], isNull);
      expect(missingReport['correctionPosition']['yMillimetres'], -103);
      expect(
        missingReport['correctionPosition']['source'],
        'manualMissingPoint',
      );
      expect(missingArchive.findFile('board_flach.png'), isNotNull);
      expect(archive.findFile('board_flach.png'), isNotNull);
      final overview = img.decodePng(
        Uint8List.fromList(
          archive.findFile('kameras_uebersicht.png')!.content as List<int>,
        ),
      )!;
      expect(overview.width, 1440);
      for (var i = 1; i <= 3; i++) {
        final picture = img.decodePng(
          Uint8List.fromList(
            archive.findFile('kamera_${i}_treffer.png')!.content as List<int>,
          ),
        )!;
        expect(picture.getPixel(0, 0).r, i * 40);
        expect(archive.findFile('kamera_${i}_vorher.png'), isNotNull);
        expect(archive.findFile('kamera_${i}_leer.png'), isNotNull);
        expect(archive.findFile('kamera_${i}_letzter_vorher.png'), isNotNull);
        expect(report['cameras'][i - 1]['axis']['confidence'], .8);
      }
    },
  );
}
