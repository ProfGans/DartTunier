import 'dart:typed_data';
import '../data/autoscore_diagnostic_export.dart';
import 'autoscoring_controller.dart';
import '../domain/frame_detector.dart';
import '../data/packed_gray_frame.dart';

AutoscoreEvidence? captureAutoscoreEvidence(
  AutoscoringController controller, {
  bool missed = false,
  bool allowPartial = false,
}) {
  if (!allowPartial &&
      (controller.cameras.length != 3 ||
          controller.cameras.any((c) => c.snapshot == null))) {
    return null;
  }
  final hit = missed ? null : controller.lastHit;
  GrayFrame? small(GrayFrame? frame) => frame?.detail == null
      ? frame
      : GrayFrame(
          frame!.width,
          frame.height,
          frame.pixels,
          sourceAspectRatio: frame.sourceAspectRatio,
        );
  PackedGrayFrame? packed(GrayFrame? frame) =>
      frame?.detail == null ? null : PackedGrayFrame.fromFrame(frame!.detail!);
  return AutoscoreEvidence(
    [
      for (var i = 0; i < controller.cameras.length; i++)
        if (controller.cameras[i].snapshot != null)
          (() {
            final c = controller.cameras[i];
            final axis = missed ? c.detectedAxis : c.lastAcceptedAxis;
            return AutoscoreCameraEvidence(
              Uint8List.fromList(c.snapshot!),
              small(missed ? c.reference : c.lastReference),
              small(c.emptyReference),
              {
                'camera': i + 1,
                'deviceName': c.description.name,
                'deviceIndex': c.deviceIndex,
                'cameraId': c.id,
                'calibrationMessage': c.calibrationMessage,
                'calibrationReused': controller.reusedCalibration,
                'imageAspectRatio': c.snapshotAspectRatio ?? c.aspectRatio,
                'calibration': c.calibration?.points
                    .map((p) => {'x': p.x, 'y': p.y})
                    .toList(),
                'lens': c.calibration?.lens.toJson(),
                'calibrationQuality': c.calibrationQuality,
                'detailResolution': c.previous?.detail == null
                    ? null
                    : {
                        'width': c.previous!.detail!.width,
                        'height': c.previous!.detail!.height,
                      },
                'axisCandidates': [
                  for (final a
                      in missed ? c.axisCandidates : c.lastAxisCandidates)
                    {
                      'a': a.a,
                      'b': a.b,
                      'c': a.c,
                      'confidence': a.confidence,
                      'outerRimOnly': a.outerRimOnly,
                    },
                ],
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
                'frameTimestampsMicroseconds': [
                  for (final f
                      in missed ? c.recentFrames : c.lastDetectionFrames)
                    f.timestampUs,
                ],
                'frameSequences': [
                  for (final f
                      in missed ? c.recentFrames : c.lastDetectionFrames)
                    f.sequence,
                ],
              },
              lastCountedBefore: small(c.lastReference),
              beforeDetail: packed(missed ? c.reference : c.lastReference),
              emptyDetail: packed(c.emptyReference),
              lastCountedBeforeDetail: packed(c.lastReference),
              beforeColor: (missed ? c.reference : c.lastReference)?.colorImage,
              emptyColor: c.emptyReference?.colorImage,
              frameColors: [
                for (final f in missed ? c.recentFrames : c.lastDetectionFrames)
                  f.colorImage,
              ],
              frameTimes: [
                for (final f in missed ? c.recentFrames : c.lastDetectionFrames)
                  f.timestampUs,
              ],
              postFrames: c.postDetectionFrames,
              frames: [
                for (final f in missed ? c.recentFrames : c.lastDetectionFrames)
                  small(f)!,
              ],
              frameDetails: [
                for (final f in missed ? c.recentFrames : c.lastDetectionFrames)
                  packed(f),
              ],
            );
          })(),
    ],
    {
      'manualMissingReport': missed,
      'environment': Map<String, Object?>.of(controller.diagnosticEnvironment),
      'recognitionStatus': controller.status,
      'recognitionRunning': controller.running,
      'waitingForEmpty': controller.waitingForEmpty,
      'countedThrows': controller.throws.length,
      'decisionReason': controller.decisionReason,
      'tipDecisionReason': controller.tipDecisionReason,
      'recognitionTimeline': controller.diagnosticTimeline,
      'lastCaptureError': controller.lastCaptureError,
      'lastCaptureErrorStack': controller.lastCaptureErrorStack,
      if (allowPartial) ...{
        'cameraStatus': controller.status,
        'recognitionRunning': controller.running,
        'missingCameraImages':
            3 - controller.cameras.where((c) => c.snapshot != null).length,
      },
      'decisionFrames': controller.decisionMetrics,
      'decisionSelectedFrame': controller.decisionSelectedFrame,
      'alternativesUsed': controller.alternativesUsed,
      'detailRefined': controller.detailRefined,
      'uncertainRecovery': controller.recoveryMetrics,
      'video': controller.videoMetrics,
      'tipContactConfirmed': controller.tipContactConfirmed,
      'spatialContact': controller.spatialContact?.toJson(),
      'tipObservations': [
        for (final t in controller.tipObservations)
          t == null
              ? null
              : {
                  'imageX': t.image.x,
                  'imageY': t.image.y,
                  'xMillimetres': t.board.x,
                  'yMillimetres': t.board.y,
                  'confidence': t.confidence,
                },
      ],
      'performance': {
        'captureAndDecodeMilliseconds': controller.captureMilliseconds,
        'processingMilliseconds': controller.processingMilliseconds,
        'nextCaptureDelayMilliseconds': controller.continuousVideo
            ? 10
            : controller.captureDelay.inMilliseconds,
      },
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
