import 'frame_detector.dart';
import 'board_geometry.dart';

/// Short-lived alternatives from this same occupied-board reference only.
/// A wobbling shaft can disappear from a later full-frame fit. Historical
/// lines remain proposals: recovery must still check current pixel evidence.
class RecentShaftEvidence {
  final _references = <GrayFrame?>[null, null, null];
  final _lines = <List<(int, DartAxis)>>[[], [], []];
  void observe(
    List<GrayFrame> references,
    List<GrayFrame> frames,
    List<DartAxis?> axes,
  ) {
    for (var i = 0; i < 3; i++) {
      if (!identical(_references[i], references[i])) {
        _lines[i].clear();
        _references[i] = references[i];
      }
      final time = frames[i].timestampUs;
      if (time == null) {
        _lines[i].clear();
        continue;
      }
      _lines[i].removeWhere((v) => time - v.$1 > 100000 || time < v.$1);
      final axis = axes[i];
      if (axis != null &&
          axis.confidence >= .8 &&
          _lines[i].every((v) => v.$1 != time)) {
        _lines[i].add((time, axis));
        if (_lines[i].length > 3) _lines[i].removeAt(0);
      }
    }
  }

  List<List<DartAxis>> alternatives(List<List<DartAxis>> current) => [
    for (var i = 0; i < 3; i++)
      [...current[i], ..._lines[i].map((v) => v.$2)].take(7).toList(),
  ];
}
