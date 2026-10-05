import '../domain/frame_detector.dart';

/// Bounded metadata-only history. No camera buffers are retained here.
class RecognitionDiagnosticTrace {
  final _entries = <Map<String, Object?>>[];
  Stopwatch? _clock;
  int _lastUs = 0;
  void clear() {
    _entries.clear();
    _clock = null;
    _lastUs = 0;
  }

  void begin(List<GrayFrame> frames, int throws) {
    _clock = Stopwatch()..start();
    _lastUs = 0;
    _entries.add({
      'throwsBefore': throws,
      'frames': [
        for (final f in frames)
          {
            'timestampMicroseconds': f.timestampUs,
            'sequence': f.sequence,
            'width': f.width,
            'height': f.height,
          },
      ],
      'stages': <Map<String, Object?>>[],
    });
    if (_entries.length > 12) _entries.removeAt(0);
  }

  void checkpoint(String phase, [Map<String, Object?> state = const {}]) {
    if (_entries.isEmpty) return;
    final elapsed = _clock?.elapsedMicroseconds ?? 0;
    (_entries.last['stages'] as List).add({
      'phase': phase,
      'milliseconds': (elapsed - _lastUs) / 1000,
      'elapsedMilliseconds': elapsed / 1000,
      'state': _copy(state),
    });
    _lastUs = elapsed;
  }

  List<Map<String, Object?>> snapshot() => [
    for (final e in _entries) (_copy(e) as Map).cast<String, Object?>(),
  ];
  static Object? _copy(Object? value) {
    if (value is Map) {
      return {for (final e in value.entries) e.key: _copy(e.value)};
    }
    if (value is List) return [for (final e in value) _copy(e)];
    return value;
  }
}
