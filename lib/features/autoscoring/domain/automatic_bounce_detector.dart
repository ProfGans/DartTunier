import 'dart:math';
import 'board_geometry.dart';
import 'frame_detector.dart';

/// A short shaft observation that disappears back to the occupied reference.
class AutomaticBounceDetector {
  int? _appearedAt, _returnedAt;
  List<double>? _transientPeak;
  int? _transientStarted;
  int _settled = 0;
  Map<String, Object?> metrics = const {};
  void reset() {
    _appearedAt = null;
    _returnedAt = null;
    _transientPeak = null;
    _transientStarted = null;
    _settled = 0;
    metrics = const {};
  }

  bool observe({
    required List<GrayFrame> reference,
    required List<GrayFrame> current,
    required List<DartAxis> axes,
    required bool stable,
    required int nowMilliseconds,
  }) {
    const detector = FrameDetector();
    final fractions = [
      for (var i = 0; i < 3; i++)
        detector.changedFraction(reference[i], current[i], threshold: 17),
    ];
    final returned = fractions.every((f) => f < .0001);
    // Some bounces only expose a blurred flight in one view. Small changes
    // from vibrating existing darts need not return to pixel-identical images.
    // Require a localized multi-camera transient, a large decline in its peak,
    // repeated settled frames and no persistent shaft evidence.
    if (_transientPeak == null &&
        fractions.any((f) => f >= .015 && f < .06) &&
        fractions.where((f) => f >= .002 && f < .06).length >= 2) {
      _transientPeak = List.of(fractions);
      _transientStarted = nowMilliseconds;
    }
    if (_transientPeak != null) {
      final elapsed = nowMilliseconds - _transientStarted!;
      if (elapsed < 0 || elapsed > 900 || fractions.any((f) => f >= .06)) {
        _transientPeak = null;
        _settled = 0;
      } else {
        final decayed = List.generate(
          3,
          (i) =>
              _transientPeak![i] >= .015 &&
              fractions[i] <= _transientPeak![i] * .45,
        ).any((v) => v);
        _settled = decayed && stable && axes.isEmpty ? _settled + 1 : 0;
        metrics = {
          'transientPeak': _transientPeak,
          'currentChanges': fractions,
          'elapsedMilliseconds': elapsed,
          'decayed': decayed,
          'settledSamples': _settled,
          'persistentAxes': axes.length,
        };
        if (_settled >= 2) {
          final accepted = {
            ...metrics,
            'reason': 'transientWithoutPersistentShaft',
          };
          reset();
          metrics = accepted;
          return true;
        }
      }
    }
    if (returned) {
      if (_appearedAt == null) return false;
      _returnedAt ??= nowMilliseconds;
      if (_returnedAt! - _appearedAt! > 900) {
        reset();
        return false;
      }
      if (stable) {
        reset();
        return true;
      }
    } else {
      if (_returnedAt != null) reset();
      if (_appearedAt == null &&
          fractions.where((f) => f > .0001 && f < .06).length >= 2 &&
          _plausibleTransientAxes(axes)) {
        _appearedAt = nowMilliseconds;
      }
    }
    return false;
  }

  // A bounce needs evidence of a passing dart, not a precise scoring position.
  // Permit a small area beyond the board where the shaft moves after impact.
  bool _plausibleTransientAxes(List<DartAxis> axes) {
    if (fuseAxes(axes) != null || decideAxes(axes) != null) return true;
    final strong = axes.where((a) => a.confidence >= .75).toList();
    for (var i = 0; i < strong.length; i++) {
      for (var j = i + 1; j < strong.length; j++) {
        final a = strong[i], b = strong[j];
        final det = a.a * b.b - b.a * a.b;
        if (det.abs() < .15) continue;
        final p = Point(
          (a.b * b.c - b.b * a.c) / det,
          (b.a * a.c - a.a * b.c) / det,
        );
        if (p.x.isFinite &&
            p.y.isFinite &&
            p.magnitude <= 300 &&
            strong.every((axis) => axis.distance(p) <= 12)) {
          return true;
        }
      }
    }
    return false;
  }
}
