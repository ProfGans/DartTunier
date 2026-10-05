import 'dart:math';
import 'board_geometry.dart';
import 'frame_detector.dart';

/// A short shaft observation that disappears back to the occupied reference.
class AutomaticBounceDetector {
  int? _appearedAt, _returnedAt;
  void reset() {
    _appearedAt = null;
    _returnedAt = null;
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
