import 'frame_detector.dart';

/// Measures capture time since the first visible shaft evidence, not physical
/// impact time. Reference changes separate successive darts automatically.
class ObservationLatency {
  List<GrayFrame>? _references;
  int? _firstEvidenceUs, _lastCaptureUs;

  Map<String, Object?> observe(
    List<GrayFrame> references,
    List<GrayFrame> frames, {
    required bool shaftEvidence,
  }) {
    if (_references == null ||
        references.length != _references!.length ||
        List.generate(
          references.length,
          (i) => !identical(references[i], _references![i]),
        ).any((v) => v)) {
      _references = List.of(references);
      _firstEvidenceUs = _lastCaptureUs = null;
    }
    final times = frames.map((f) => f.timestampUs).whereType<int>().toList();
    if (times.length != 3) return {};
    final now = times.reduce((a, b) => a > b ? a : b);
    if (_lastCaptureUs != null && now <= _lastCaptureUs!) return {};
    _lastCaptureUs = now;
    if (shaftEvidence) _firstEvidenceUs ??= now;
    return {
      'firstShaftEvidenceCaptureTimestampMicroseconds': _firstEvidenceUs,
      'shaftEvidenceToCurrentCaptureMilliseconds': _firstEvidenceUs == null
          ? null
          : (now - _firstEvidenceUs!) / 1000,
      'physicalImpactTimestampAvailable': false,
    };
  }
}
