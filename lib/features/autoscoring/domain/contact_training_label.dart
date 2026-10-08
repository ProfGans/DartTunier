/// Independently reviewed image labels, never inferred from board calibration.
Map<String, Object?> contactTrainingLabel({
  required int camera,
  required bool? occluded,
  required bool reviewed,
  Map<String, double>? tip,
  List<Map<String, double>> shaft = const [],
}) {
  bool valid(Map<String, double>? p) =>
      p != null &&
      ['x', 'y'].every(
        (k) => p[k] != null && p[k]!.isFinite && p[k]! >= 0 && p[k]! <= 1,
      );
  final shaftValid =
      shaft.length == 2 &&
      shaft.every(valid) &&
      ((shaft[0]['x']! - shaft[1]['x']!).abs() +
              (shaft[0]['y']! - shaft[1]['y']!).abs()) >
          .005;
  final eligible =
      reviewed && occluded != null && (occluded || (valid(tip) && shaftValid));
  return {
    'schemaVersion': 1,
    'camera': camera,
    'reviewed': reviewed,
    'occluded': occluded,
    'verifiedImagePoint': occluded == true ? null : tip,
    'shaftEndpoints': shaft,
    'trainingEligible': eligible,
    'labelSource': 'manualOriginalImageReview',
    'imageContext': 'latestSnapshot',
    'reviewedAtUtc': reviewed ? DateTime.now().toUtc().toIso8601String() : null,
  };
}
