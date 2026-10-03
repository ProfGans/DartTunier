import 'dart:typed_data';
import '../data/autoscore_diagnostic_export.dart';
import 'autoscoring_controller.dart';
import '../domain/frame_detector.dart';

AutoscoreEvidence? captureAutoscoreEvidence(
  AutoscoringController controller, {
  bool missed = false,
}) {
  if (controller.cameras.length != 3 ||
      controller.cameras.any((c) => c.snapshot == null)) {
    return null;
  }
  final hit = missed ? null : controller.lastHit;
  return AutoscoreEvidence(
    [
      for (var i = 0; i < controller.cameras.length; i++)
        (() {
          final c = controller.cameras[i];
          final axis = missed ? c.detectedAxis : c.lastAcceptedAxis;
          return AutoscoreCameraEvidence(
            Uint8List.fromList(c.snapshot!),
            missed ? c.reference : c.lastReference,
            c.emptyReference,
            {
              'camera': i + 1,
              'imageAspectRatio': c.snapshotAspectRatio ?? c.aspectRatio,
              'calibration': c.calibration?.points
                  .map((p) => {'x': p.x, 'y': p.y})
                  .toList(),
              'axis': axis == null
                  ? null
                  : {
                      'a': axis.a,
                      'b': axis.b,
                      'c': axis.c,
                      'confidence': axis.confidence,
                      'outerRimOnly': axis.outerRimOnly,
                    },
              'changedFraction': c.changeFraction,
              'referenceChangedFraction':
                  c.reference == null || c.previous == null
                  ? null
                  : const FrameDetector().changedFraction(
                      c.reference!,
                      c.previous!,
                    ),
              'lastReferenceChangedFraction':
                  c.lastReference == null || c.previous == null
                  ? null
                  : const FrameDetector().changedFraction(
                      c.lastReference!,
                      c.previous!,
                    ),
              'stableSamples': c.stable,
            },
            lastCountedBefore: c.lastReference,
          );
        })(),
    ],
    {
      'manualMissingReport': missed,
      if (hit != null) ...{
        'xMillimetres': hit.point.x,
        'yMillimetres': hit.point.y,
        'residualMillimetres': hit.residual,
        'views': hit.views,
        'needsReview': hit.needsReview,
        'forcedDecision': hit.forcedDecision,
      },
    },
  );
}
