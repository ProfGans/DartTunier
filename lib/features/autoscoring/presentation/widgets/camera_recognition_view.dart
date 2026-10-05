import 'dart:math';
import 'package:flutter/material.dart';
import '../../application/autoscoring_controller.dart';
import '../../domain/automatic_board_calibration.dart';
import '../../domain/board_geometry.dart';

class CameraRecognitionView extends StatelessWidget {
  const CameraRecognitionView({
    super.key,
    required this.camera,
    this.hit,
    this.showRecognition = true,
    this.showColorSamples = false,
  });
  final AutoscoreCamera camera;
  final FusedHit? hit;
  final bool showRecognition, showColorSamples;
  @override
  Widget build(BuildContext context) => ClipRect(
    child: AspectRatio(
      aspectRatio: camera.snapshotAspectRatio ?? camera.aspectRatio,
      child: camera.snapshot == null
          ? const Center(child: Icon(Icons.videocam_outlined))
          : Stack(
              fit: StackFit.expand,
              children: [
                Image.memory(
                  camera.snapshot!,
                  gaplessPlayback: true,
                  fit: BoxFit.contain,
                ),
                if (showRecognition)
                  IgnorePointer(
                    child: CustomPaint(
                      painter: RecognitionOverlayPainter(
                        diagnostics: camera.diagnostics,
                        calibration: camera.calibration,
                        candidateCalibration: camera.candidateCalibration,
                        axis: camera.detectedAxis,
                        changes: camera.changedPixels,
                        hit: hit,
                        showColorSamples: showColorSamples,
                      ),
                    ),
                  ),
              ],
            ),
    ),
  );
}

class RecognitionOverlayPainter extends CustomPainter {
  const RecognitionOverlayPainter({
    this.diagnostics,
    this.calibration,
    this.candidateCalibration,
    this.axis,
    this.hit,
    this.changes = const [],
    this.showColorSamples = false,
  });
  final BoardDetectionDiagnostics? diagnostics;
  final BoardCalibration? calibration, candidateCalibration;
  final DartAxis? axis;
  final FusedHit? hit;
  final List<BoardPoint> changes;
  final bool showColorSamples;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    Offset at(BoardPoint p) => Offset(p.x * size.width, p.y * size.height);
    void label(String value, Offset p, Color color) {
      final text = TextPainter(
        text: TextSpan(
          text: value,
          style: TextStyle(
            color: color,
            backgroundColor: Colors.black87,
            fontSize: 12,
            fontWeight: FontWeight.bold,
            fontFamily: 'Roboto',
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: max(1, size.width - 4));
      text.paint(
        canvas,
        Offset(
          (p.dx + 7).clamp(2, max(2, size.width - text.width - 2)),
          (p.dy - text.height - 3).clamp(
            2,
            max(2, size.height - text.height - 2),
          ),
        ),
      );
    }

    void cross(Offset p, Color color, double radius) {
      final paint = Paint()
        ..color = color
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;
      canvas.drawCircle(p, radius, paint);
      canvas.drawLine(
        p - Offset(radius + 3, 0),
        p + Offset(radius + 3, 0),
        paint,
      );
      canvas.drawLine(
        p - Offset(0, radius + 3),
        p + Offset(0, radius + 3),
        paint,
      );
    }

    if (showColorSamples && diagnostics != null) {
      final paint = Paint()..color = Colors.yellow.withValues(alpha: .5);
      for (final p in diagnostics!.colorSamples) {
        canvas.drawCircle(at(p), 1, paint);
      }
    }
    final changePaint = Paint()
      ..color = Colors.cyanAccent.withValues(alpha: .5);
    for (final p in changes) {
      canvas.drawCircle(at(p), 1.2, changePaint);
    }
    final transform = calibration ?? candidateCalibration;
    final outline = diagnostics?.outline;
    final color = calibration != null
        ? Colors.greenAccent
        : Colors.orangeAccent;
    if (transform != null || outline != null) {
      final safePerspective =
          outline != null && outline.ellipsePoint(outline.bull).magnitude < .8;
      BoardPoint map(BoardPoint p) => transform != null
          ? transform.unproject(p)
          : safePerspective
          ? outline.unrectify(p * (1 / 170))
          : outline!.imagePoint(p * (1 / 170));
      for (final radius in [170.0, 162.0, 107.0, 99.0, 15.9]) {
        final path = Path();
        for (var i = 0; i <= 96; i++) {
          final p = at(
            map(Point(sin(i * pi / 48) * radius, -cos(i * pi / 48) * radius)),
          );
          if (i == 0) {
            path.moveTo(p.dx, p.dy);
          } else {
            path.lineTo(p.dx, p.dy);
          }
        }
        canvas.drawPath(
          path,
          Paint()
            ..color = color
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.4,
        );
      }
      if (calibration != null) {
        // This is the calibrated detection limit, not a detected physical edge.
        final rimPaint = Paint()
          ..color = Colors.lightBlueAccent
          ..strokeWidth = 1.6;
        for (var i = 0; i < 96; i += 2) {
          BoardPoint rim(int step) => map(
            Point(
              sin(step * pi / 48) * BoardGeometry.detectionRadius,
              -cos(step * pi / 48) * BoardGeometry.detectionRadius,
            ),
          );
          canvas.drawLine(at(rim(i)), at(rim(i + 1)), rimPaint);
        }
      }
      final bull = at(
        transform != null ? map(const Point(0, 0)) : outline!.bull,
      );
      cross(bull, color, 4);
      label('Bull', bull, color);
      if (transform != null) {
        const values = ['20', '6', '3', '11'];
        for (var i = 0; i < 4; i++) {
          final p = at(transform.points[i]);
          canvas.drawCircle(p, 4, Paint()..color = color);
          label(values[i], p, color);
        }
      }
    } else if (diagnostics != null) {
      for (var i = 0; i < diagnostics!.bullCandidates.length; i++) {
        final p = at(diagnostics!.bullCandidates[i]);
        cross(p, Colors.redAccent, 5);
        label('Bull? ${i + 1}', p, Colors.redAccent);
      }
    }
    if (calibration != null) {
      if (axis != null) {
        final segment = calibration!.imageAxis(axis!);
        if (segment.length >= 2) {
          final path = Path()
            ..moveTo(at(segment.first).dx, at(segment.first).dy);
          for (final point in segment.skip(1)) {
            path.lineTo(at(point).dx, at(point).dy);
          }
          canvas.drawPath(
            path,
            Paint()
              ..style = PaintingStyle.stroke
              ..color = Colors.cyanAccent
              ..strokeWidth = 2.5,
          );
        }
      }
      if (hit != null) {
        final p = at(calibration!.unproject(hit!.point));
        cross(p, Colors.pinkAccent, 7);
        label(
          '${BoardGeometry.score(hit!.point).label}${hit!.needsReview ? ' ?' : ''}',
          p,
          Colors.pinkAccent,
        );
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant RecognitionOverlayPainter oldDelegate) => true;
}

class RecognitionLegend extends StatelessWidget {
  const RecognitionLegend({super.key});
  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 16,
    runSpacing: 8,
    children: [
      for (final entry in [
        (Colors.green, 'Freigegebene Ringe / Bull'),
        (Colors.orange, 'Kalibrierungsvorschlag'),
        (Colors.red, 'Bull-Kandidat'),
        (Colors.blue, 'Bildänderung / Dartachse'),
        (Colors.pink, 'Erkannter Treffer'),
        (Colors.lightBlueAccent, 'Außenrand · 0 Punkte (Kalibrierung)'),
        (Colors.amber, 'Farbpixel (optional)'),
      ])
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.circle, size: 12, color: entry.$1),
            const SizedBox(width: 6),
            Flexible(child: Text(entry.$2)),
          ],
        ),
    ],
  );
}

class CameraRecognitionDetails extends StatelessWidget {
  const CameraRecognitionDetails({super.key, required this.camera});
  final AutoscoreCamera camera;
  @override
  Widget build(BuildContext context) {
    final diagnostics = camera.diagnostics;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (diagnostics != null) ...[
          const SizedBox(height: 8),
          Text(
            '${diagnostics.stage} · Farbfilter ${diagnostics.selectiveColors ? 2 : 1}\n${diagnostics.colorCount} Farbpixel · ${diagnostics.bullCandidates.length} Bull-Kandidaten',
          ),
          Text(
            diagnostics.progress >= 3
                ? 'Ringabdeckung: Double ${diagnostics.doubleBins}/40 · Triple ${diagnostics.tripleBins}/40'
                : 'Ringabdeckung noch nicht geprüft.',
          ),
        ],
        if (camera.reference != null)
          Text(
            'Bildbewegung ${(camera.changeFraction * 100).toStringAsFixed(2)} % · ${camera.stable} ruhige Abtastungen',
          ),
      ],
    );
  }
}
