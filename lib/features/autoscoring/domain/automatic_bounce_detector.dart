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
        detector.changedFraction(reference[i], current[i]),
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
          fuseAxes(axes) != null) {
        _appearedAt = nowMilliseconds;
      }
    }
    return false;
  }
}
