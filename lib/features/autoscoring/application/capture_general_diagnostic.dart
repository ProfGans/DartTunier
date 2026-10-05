import 'autoscoring_controller.dart';
import 'capture_autoscore_evidence.dart';
import '../data/autoscore_diagnostic_export.dart';

/// Snapshot before any dialog or manual reset, including incomplete startup.
AutoscoreEvidence captureGeneralDiagnostic(
  AutoscoringController controller, {
  String? setupId,
}) {
  final evidence = captureAutoscoreEvidence(
    controller,
    missed: true,
    allowPartial: true,
  )!;
  evidence.hit.addAll({
    'eventType': 'generalDiagnostic',
    'manualMissingReport': false,
    'setupId': setupId,
    'busy': controller.busy,
    'removalMetrics': [
      for (final metrics in controller.removalMetrics)
        Map<String, Object?>.of(metrics),
    ],
    'availableCameras': [
      for (final camera in controller.available) camera.name,
    ],
    'cameraStates': [
      for (final camera in controller.cameras)
        {
          'deviceName': camera.description.name,
          'deviceIndex': camera.deviceIndex,
          'hasImage': camera.snapshot != null,
          'calibrated': camera.calibration != null,
          'calibrationMessage': camera.calibrationMessage,
        },
    ],
    'throws': [
      for (final dart in controller.throws)
        {'label': dart.label, 'points': dart.scoredPoints},
    ],
  });
  // Current frames describe this report, not the previous accepted throw.
  evidence.hit['decisionSelectedFrame'] = null;
  evidence.hit['imageContext'] = 'currentStateAtManualReport';
  return evidence;
}
