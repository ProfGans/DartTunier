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
import 'contact_audit.dart';
import 'diagnostic_capture_metrics.dart';

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
    this.beforeColor,
    this.emptyColor,
    this.frameColors = const [],
    this.frameTimes = const [],
    this.postFrames = const [],
  });
  final Uint8List image;
  final GrayFrame? before, empty;
  final GrayFrame? lastCountedBefore;
  final List<GrayFrame> frames;
  final PackedGrayFrame? beforeDetail, emptyDetail, lastCountedBeforeDetail;
  final List<PackedGrayFrame?> frameDetails;
  final Map<String, Object?> metadata;
  final Uint8List? beforeColor, emptyColor;
  final List<Uint8List?> frameColors;
  final List<int?> frameTimes;
  final List<GrayFrame> postFrames;
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
    var hasContactAudit = false;
    final captureMetrics = <Map<String, Object?>>[];
    void add(String name, List<int> bytes) =>
        archive.addFile(ArchiveFile(name, bytes.length, bytes));
    void color(String name, Uint8List? bytes) {
      if (bytes == null) return;
      final image = img.decodeImage(bytes);
      if (image == null) throw FormatException('Unlesbares Farbbild: $name');
      add(name, img.encodeJpg(image, quality: 90));
    }

    Uint8List? gray(String name, GrayFrame? frame) {
      if (frame == null) return null;
      final image = img.Image(width: frame.width, height: frame.height);
      for (var y = 0; y < frame.height; y++) {
        for (var x = 0; x < frame.width; x++) {
          final v = frame.pixels[y * frame.width + x];
          image.setPixelRgb(x, y, v, v, v);
        }
      }
      final bytes = Uint8List.fromList(img.encodePng(image));
      add(name, bytes);
      return bytes;
    }

    final previews = <img.Image>[];
    for (var i = 0; i < evidence.cameras.length; i++) {
      final camera = evidence.cameras[i];
      final image = img.decodeImage(camera.image);
      if (image == null) throw StateError('Kamerabild ${i + 1} ist unlesbar.');
      add('kamera_${i + 1}_treffer.png', img.encodePng(image));
      previews.add(img.copyResize(image, width: 480));
      final selected = evidence.hit['decisionSelectedFrame'];
      final decisions = evidence.hit['decisionFrames'];
      final selectedTimes =
          selected is int &&
              decisions is List &&
              selected >= 0 &&
              selected < decisions.length
          ? (decisions[selected] as Map)['captureTimestampsMicroseconds']
          : null;
      final cameraNumber = camera.metadata['camera'];
      final cameraIndex = cameraNumber is int ? cameraNumber - 1 : i;
      final selectedTime =
          selectedTimes is List &&
              cameraIndex >= 0 &&
              cameraIndex < selectedTimes.length
          ? selectedTimes[cameraIndex]
          : null;
      final sourceIndex = selectedTime is int
          ? camera.frameTimes.indexOf(selectedTime)
          : -1;
      Uint8List? selectedImage;
      if (sourceIndex >= 0 && sourceIndex < camera.frames.length) {
        selectedImage = gray(
          'kamera_${i + 1}_entscheidung.png',
          camera.frames[sourceIndex],
        );
        gray(
          'kamera_${i + 1}_entscheidung_detail.png',
          sourceIndex < camera.frameDetails.length
              ? camera.frameDetails[sourceIndex]?.unpack()
              : camera.frames[sourceIndex].detail,
        );
        if (sourceIndex < camera.frameColors.length) {
          final selectedColor = camera.frameColors[sourceIndex];
          if (selectedColor != null) {
            selectedImage = selectedColor;
            add('kamera_${i + 1}_entscheidung_farbe.jpg', selectedColor);
          }
        }
      }
      final qualityFrame =
          sourceIndex >= 0 && sourceIndex < camera.frames.length
          ? camera.frames[sourceIndex]
          : camera.frames.isEmpty
          ? null
          : camera.frames.last;
      captureMetrics.add({
        'camera': camera.metadata['camera'] ?? i + 1,
        'imageQuality': qualityFrame == null
            ? null
            : diagnosticImageQuality(qualityFrame),
        'qualitySource': sourceIndex >= 0
            ? 'selectedDecisionSequenceFrame'
            : 'lastSavedSequenceFrame',
        'selectedSequenceIndex': sourceIndex < 0 ? null : sourceIndex,
        'selectedTimestampMicroseconds': selectedTime,
        'cadence': diagnosticCaptureCadence(
          camera.frameTimes,
          ((camera.metadata['frameSequences'] as List?) ?? []).cast<int?>(),
        ),
      });
      final audit = buildContactAudit(
        selectedImage ?? camera.image,
        camera.metadata,
        evidence.hit,
        correctionPosition,
        emptyColor: camera.emptyColor,
      );
      if (audit != null) {
        audit.metrics['imageSource'] = selectedImage == null
            ? 'latestDetectionImageFallback'
            : 'selectedDecisionFrame';
        hasContactAudit = true;
        add('kamera_${i + 1}_kontaktpruefung.png', audit.overlay);
        add(
          'kamera_${i + 1}_kontaktpruefung.json',
          utf8.encode(
            const JsonEncoder.withIndent('  ').convert(audit.metrics),
          ),
        );
      }
      gray('kamera_${i + 1}_vorher.png', camera.before);
      if (camera.beforeColor != null) {
        color('kamera_${i + 1}_vorher_farbe.jpg', camera.beforeColor!);
      }
      if (camera.emptyColor != null) {
        color('kamera_${i + 1}_leer_farbe.jpg', camera.emptyColor!);
      }
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
        if (f < camera.frameColors.length && camera.frameColors[f] != null) {
          color(
            'kamera_${i + 1}_sequenz_${f + 1}_farbe.jpg',
            camera.frameColors[f]!,
          );
        }
        gray('kamera_${i + 1}_sequenz_${f + 1}.png', camera.frames[f]);
        gray(
          'kamera_${i + 1}_sequenz_${f + 1}_detail.png',
          f < camera.frameDetails.length
              ? camera.frameDetails[f]?.unpack()
              : camera.frames[f].detail,
        );
      }
      for (var f = 0; f < camera.postFrames.length; f++) {
        final frame = camera.postFrames[f];
        gray('kamera_${i + 1}_nachher_${f + 1}.png', frame);
        if (frame.colorImage != null) {
          color(
            'kamera_${i + 1}_nachher_${f + 1}_farbe.jpg',
            frame.colorImage!,
          );
        }
      }
      final clip = <(Uint8List, int?)>[
        for (var f = 0; f < camera.frameColors.length; f++)
          if (camera.frameColors[f] != null)
            (
              camera.frameColors[f]!,
              f < camera.frameTimes.length ? camera.frameTimes[f] : null,
            ),
        for (final frame in camera.postFrames)
          if (frame.colorImage != null) (frame.colorImage!, frame.timestampUs),
      ];
      if (clip.length >= 2) {
        final encoder = img.GifEncoder();
        for (var f = 0; f < clip.length; f++) {
          final source = img.decodeImage(clip[f].$1)!;
          final elapsed =
              f + 1 < clip.length &&
                  clip[f].$2 != null &&
                  clip[f + 1].$2 != null
              ? (clip[f + 1].$2! - clip[f].$2!) ~/ 10000
              : 5;
          encoder.addFrame(
            img.copyResize(source, width: 360),
            duration: elapsed.clamp(2, 100),
          );
        }
        add('kamera_${i + 1}_ablauf.gif', encoder.finish()!);
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
    if (hasContactAudit) {
      add(
        'KONTAKTPRUEFUNG.txt',
        utf8.encode(
          'Cyan: kalibrierte Ringe und Segmentgrenzen (230 mm = Suchgrenze). '
          'Gelb: gewaehlte Schaftachse. Pink: erkannte Position. Gruen: manuelle '
          'Korrektur, in das Originalkamerabild zurueckprojiziert. '
          'JSON-Dateien enthalten Achsenabstaende und Farbabdeckung der Ringmitten '
          'im Leerbild, wenn ein Farbleerbild vorhanden ist. Diese Farbpruefung '
          'bestaetigt weder die Zahlenausrichtung noch den echten Pfeilkontakt. '
          'Korrekturpunkte werden nicht zur laufenden Erkennung verwendet.',
        ),
      );
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
          'schemaVersion': 8,
          'capturedAtUtc': evidence.capturedAt.toIso8601String(),
          'detected': detected,
          'corrected': corrected,
          'correctDetection': evidence.hit['eventType'] == 'manualRemoval'
              ? null
              : false,
          'hit': evidence.hit,
          'correctionPosition': correctionPosition,
          'cameras': evidence.cameras
              .map(
                (camera) => {
                  ...camera.metadata,
                  'postFrames': [
                    for (final frame in camera.postFrames)
                      {
                        'timestampMicroseconds': frame.timestampUs,
                        'sequence': frame.sequence,
                      },
                  ],
                },
              )
              .toList(),
        }),
      ),
    );
    add(
      'diagnose_zusammenfassung.json',
      utf8.encode(
        const JsonEncoder.withIndent('  ').convert({
          'schemaVersion': 1,
          'reportSchemaVersion': 8,
          'environment': evidence.hit['environment'],
          'detected': detected,
          'corrected': corrected,
          'decisionReason': evidence.hit['decisionReason'],
          'tipDecisionReason': evidence.hit['tipDecisionReason'],
          'waitingForEmpty': evidence.hit['waitingForEmpty'],
          'recognitionStatus': evidence.hit['recognitionStatus'],
          'cameras': captureMetrics,
          'timingScope':
              'Stage durations exclude capture/decoding. At detection callback the last stage can still be running.',
        }),
      ),
    );
    add(
      'DIAGNOSE_UEBERSICHT.txt',
      utf8.encode(
        'Erkannt: $detected\nKorrigiert: $corrected\n'
        'Berichtstyp: ${evidence.hit['eventType'] ?? 'Trefferkorrektur'}\n'
        'Fehlerbeschreibung: ${evidence.hit['userDescription'] ?? 'keine'}\n'
        'Auswahlgrund: ${evidence.hit['decisionReason'] ?? 'nicht protokolliert'}\n'
        'Spitzenpruefung: ${evidence.hit['tipDecisionReason'] ?? 'nicht protokolliert'}\n'
        'Status: ${evidence.hit['recognitionStatus'] ?? 'nicht protokolliert'}\n'
        'Details: diagnose_zusammenfassung.json und bericht.json. '
        'entscheidung-Bilder sind die tatsaechlich ausgewaehlten Frames, sofern '
        'deren Zeitstempel vorhanden sind. Treffer-Bilder bleiben die letzten '
        'Originalaufnahmen der Erkennung. Zeitabstaende basieren auf PC-Ankunft, '
        'nicht auf Hardware-Synchronisation. Bildqualitaet ist eine Kennzahl des '
        'gesamten Bilds, keine sichere Fokusdiagnose. Fuer aeltere Berichte '
        'koennen Entscheidungsgruende und Zeitinformationen fehlen.',
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
        evidence.hit['eventType'] == 'generalDiagnostic'
            ? 'Allgemeine Diagnose: Bilder und Zustand wurden beim Druecken des Diagnosebuttons gesichert. Keine Trefferkorrektur und kein Reset. Fehlende Kamerabilder werden im Bericht ausgewiesen. userDescription enthaelt die optionale Fehlerbeschreibung.'
            : evidence.hit['eventType'] == 'manualRemoval'
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
      '${target.path}/${evidence.hit['eventType'] == 'generalDiagnostic'
          ? 'diagnose'
          : evidence.hit['eventType'] == 'manualRemoval'
          ? 'herausziehen'
          : 'korrektur'}_${DateTime.now().microsecondsSinceEpoch}.zip',
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
