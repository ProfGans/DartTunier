import 'board_geometry.dart';
import 'frame_detector.dart';

/// Admit stationary shafts despite slight vibration; position confirmation
/// still requires the existing temporal decision window.
class ShaftFrameStability {
  final _previous = <int, (GrayFrame, DartAxis, int, double)>{};
  bool observe(
    int camera,
    GrayFrame reference,
    GrayFrame frame,
    DartAxis? axis,
    double motionFraction,
  ) {
    final before = _previous[camera];
    final time = frame.timestampUs;
    if (axis == null || time == null || axis.confidence < .9) {
      _previous.remove(camera);
      return false;
    }
    _previous[camera] = (reference, axis, time, motionFraction);
    if (before == null ||
        !identical(before.$1, reference) ||
        time <= before.$3 ||
        time - before.$3 > 100000 ||
        motionFraction >= .006 ||
        before.$4 >= .006) {
      return false;
    }
    final previous = before.$2;
    final sign = axis.a * previous.a + axis.b * previous.b >= 0 ? 1 : -1;
    return (axis.a * previous.b - axis.b * previous.a).abs() <= .005 &&
        (axis.c * sign - previous.c).abs() <= .7;
  }
}
