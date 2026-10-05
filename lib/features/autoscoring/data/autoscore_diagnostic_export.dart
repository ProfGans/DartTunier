import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import '../domain/frame_detector.dart';
import '../domain/flat_board_projection.dart';
import '../domain/board_geometry.dart';
import '../domain/lens_distortion.dart';
import '../domain/correction_analysis.dart';
import 'packed_gray_frame.dart';

class AutoscoreCameraEvidence {
  const AutoscoreCameraEvidence(
    this.image,
    this.before,
    this.empty,
    this.metadata, {
    this.lastCountedBefore,
    this.frames = const [],
    this.beforeDetail,
    this.emptyDetail,
    this.lastCountedBeforeDetail,
    this.frameDetails = const [],
  });
  final Uint8List image;
  final GrayFrame? before, empty;
  final GrayFrame? lastCountedBefore;
  final List<GrayFrame> frames;
  final PackedGrayFrame? beforeDetail, emptyDetail, lastCountedBeforeDetail;
  final List<PackedGrayFrame?> frameDetails;
  final Map<String, Object?> metadata;
}

class AutoscoreEvidence {
  AutoscoreEvidence(this.cameras, this.hit, {DateTime? capturedAt})
    : capturedAt = capturedAt ?? DateTime.now().toUtc();
  final List<AutoscoreCameraEvidence> cameras;
  final Map<String, Object?> hit;
  final DateTime capturedAt;
}

class AutoscoreDiagnosticExport {
  const AutoscoreDiagnosticExport();

  Uint8List encode(
    AutoscoreEvidence evidence,
    String detected,
    String corrected, {
    Map<String, Object?>? correctionPosition,
  }) {
    final archive = Archive();
    void add(String name, List<int> bytes) =>
        archive.addFile(ArchiveFile(name, bytes.length, bytes));
    void gray(String name, GrayFrame? frame) {
      if (frame == null) return;
      final image = img.Image(width: frame.width, height: frame.height);
      for (var y = 0; y < frame.height; y++) {
        for (var x = 0; x < frame.width; x++) {
          final v = frame.pixels[y * frame.width + x];
          image.setPixelRgb(x, y, v, v, v);
        }
      }
      add(name, img.encodePng(image));
    }

    final previews = <img.Image>[];
    for (var i = 0; i < evidence.cameras.length; i++) {
      final camera = evidence.cameras[i];
      final image = img.decodeImage(camera.image);
      if (image == null) throw StateError('Kamerabild ${i + 1} ist unlesbar.');
      add('kamera_${i + 1}_treffer.png', img.encodePng(image));
      previews.add(img.copyResize(image, width: 480));
      gray('kamera_${i + 1}_vorher.png', camera.before);
      gray('kamera_${i + 1}_leer.png', camera.empty);
      gray('kamera_${i + 1}_letzter_vorher.png', camera.lastCountedBefore);
      gray(
        'kamera_${i + 1}_vorher_detail.png',
        camera.beforeDetail?.unpack() ?? camera.before?.detail,
      );
      gray(
        'kamera_${i + 1}_leer_detail.png',
        camera.emptyDetail?.unpack() ?? camera.empty?.detail,
      );
      gray(
        'kamera_${i + 1}_letzter_vorher_detail.png',
        camera.lastCountedBeforeDetail?.unpack() ??
            camera.lastCountedBefore?.detail,
      );
      for (var f = 0; f < camera.frames.length; f++) {
        gray('kamera_${i + 1}_sequenz_${f + 1}.png', camera.frames[f]);
        gray(
          'kamera_${i + 1}_sequenz_${f + 1}_detail.png',
          f < camera.frameDetails.length
              ? camera.frameDetails[f]?.unpack()
              : camera.frames[f].detail,
        );
      }
    }
    if (previews.isNotEmpty) {
      final height = previews
          .map((p) => p.height)
          .reduce((a, b) => a > b ? a : b);
      final overview = img.Image(
        width: previews.length * 480,
        height: height + 36,
      );
      img.fill(overview, color: img.ColorRgb8(245, 245, 245));
      for (var i = 0; i < previews.length; i++) {
        img.drawString(
          overview,
          'Kamera ${i + 1}',
          font: img.arial24,
          x: i * 480 + 8,
          y: 4,
          color: img.ColorRgb8(20, 20, 20),
        );
        img.compositeImage(overview, previews[i], dstX: i * 480, dstY: 36);
      }
      add('kameras_uebersicht.png', img.encodePng(overview));
    }
    final flatCameras = [
      for (final camera in evidence.cameras)
        if (camera.metadata['calibration'] is List)
          FlatBoardCamera(
            camera.image,
            BoardCalibration(
              [
                for (final p in camera.metadata['calibration'] as List)
                  BoardPoint(
                    (p['x'] as num).toDouble(),
                    (p['y'] as num).toDouble(),
                  ),
              ],
              lens: camera.metadata['lens'] is Map
                  ? LensDistortion.fromJson(camera.metadata['lens'] as Map)
                  : const LensDistortion(),
            ),
          ),
    ];
    if (flatCameras.isNotEmpty) {
      final flat = img.decodePng(projectFlatBoard(flatCameras))!;
      void marker(Map<String, Object?> values, img.Color color) {
        final x = values['xMillimetres'], y = values['yMillimetres'];
        if (x is! num || y is! num) return;
        img.drawCircle(
          flat,
          x: ((x / BoardGeometry.flatViewDiameter + .5) * 479).round(),
          y: ((y / BoardGeometry.flatViewDiameter + .5) * 479).round(),
          radius: 5,
          color: color,
        );
      }

      marker(evidence.hit, img.ColorRgb8(255, 40, 140));
      if (correctionPosition != null) {
        marker(correctionPosition, img.ColorRgb8(50, 255, 80));
      }
      add('board_flach.png', img.encodePng(flat));
    }
    add(
      'bericht.json',
      utf8.encode(
        const JsonEncoder.withIndent('  ').convert({
          'schemaVersion': 5,
          'capturedAtUtc': evidence.capturedAt.toIso8601String(),
          'detected': detected,
          'corrected': corrected,
          'correctDetection': evidence.hit['eventType'] == 'manualRemoval'
              ? null
              : false,
          'hit': evidence.hit,
          'correctionPosition': correctionPosition,
          'cameras': evidence.cameras.map((camera) => camera.metadata).toList(),
        }),
      ),
    );
    final x = correctionPosition?['xMillimetres'],
        y = correctionPosition?['yMillimetres'],
        detectedX = evidence.hit['xMillimetres'],
        detectedY = evidence.hit['yMillimetres'];
    final analysis = analysePositionCorrections([
      if (x is num && y is num)
        PositionCorrectionSample(
          BoardPoint(x.toDouble(), y.toDouble()),
          detectedX is num && detectedY is num
              ? BoardPoint(detectedX.toDouble(), detectedY.toDouble())
              : null,
          [
            for (final camera in evidence.cameras)
              (camera.metadata['axis'] as Map?)?.cast<String, Object?>(),
          ],
        ),
    ]);
    add(
      'korrektur_auswertung.json',
      utf8.encode(
        const JsonEncoder.withIndent('  ').convert({
          'schemaVersion': 1,
          'currentCorrection': analysis,
          'session': evidence.hit['correctionHistoryAnalysis'],
        }),
      ),
    );
    add(
      'LESEN.txt',
      utf8.encode(
        evidence.hit['eventType'] == 'manualRemoval'
            ? 'Manuell bestaetigtes Herausziehen: Kamerabilder zeigen das Board unmittelbar vor dem Reset. Vorherbilder zeigen die belegte Referenz, Leerbilder die bisherige leere Referenz. bericht.json enthaelt den blockierten Zustand und die Aufnahme. Dies ist keine Trefferkorrektur.'
            : 'Kamerabilder stammen vom Zeitpunkt der automatischen Treffererkennung, nicht vom spaeteren Korrigieren. Trefferbilder sind Originalaufnahmen. Vorher- und Leerbilder sind die tatsaechlichen Graustufen-Referenzen der Erkennung. bericht.json enthaelt Kalibrierung, Achsen, berechnete Position und Korrektur.',
      ),
    );
    return Uint8List.fromList(ZipEncoder().encode(archive));
  }

  Future<String> save(
    AutoscoreEvidence evidence,
    String detected,
    String corrected, {
    Directory? directory,
    Map<String, Object?>? correctionPosition,
  }) async {
    final target =
        directory ??
        Directory(
          '${(await getApplicationDocumentsDirectory()).path}/Autoscore-Diagnosen',
        );
    await target.create(recursive: true);
    final file = File(
      '${target.path}/${evidence.hit['eventType'] == 'manualRemoval' ? 'herausziehen' : 'korrektur'}_${DateTime.now().microsecondsSinceEpoch}.zip',
    );
    await file.writeAsBytes(
      await compute(encodeAutoscoreDiagnostic, (
        evidence,
        detected,
        corrected,
        correctionPosition,
      )),
    );
    return file.path;
  }
}

Uint8List encodeAutoscoreDiagnostic(
  (AutoscoreEvidence, String, String, Map<String, Object?>?) request,
) => const AutoscoreDiagnosticExport().encode(
  request.$1,
  request.$2,
  request.$3,
  correctionPosition: request.$4,
);
