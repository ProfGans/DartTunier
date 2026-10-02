import 'frame_detector.dart';

enum VisitResetState { playing, waitingForEmpty, cleared }

/// Compare against both the original empty board and the last counted darts.
/// A partial removal must never be interpreted as another thrown dart.
class AutomaticVisitReset {
  bool waitingForEmpty = false;
  int _emptySamples = 0;

  void reset() {
    waitingForEmpty = false;
    _emptySamples = 0;
  }

  VisitResetState observe({
    required List<GrayFrame> empty,
    required List<GrayFrame> occupied,
    required List<GrayFrame> current,
    required bool stable,
    required int darts,
    int? dartLimit = 3,
  }) {
    if (darts == 0) return VisitResetState.playing;
    const detector = FrameDetector();
    // A bounce leaves no dart behind; an already empty board is not removal.
    if (List.generate(
          3,
          (i) => detector.changedFraction(empty[i], occupied[i]),
        ).where((fraction) => fraction > .0001).length <
        2) {
      return VisitResetState.playing;
    }
    var clearViews = 0, removalViews = 0;
    for (var i = 0; i < 3; i++) {
      final before = detector.changedFraction(empty[i], occupied[i]);
      final now = detector.changedFraction(empty[i], current[i]);
      final tolerance = (before * .12).clamp(.00003, .0005);
      if (now <= tolerance) clearViews++;
      var removed = 0, added = 0;
      for (var p = 0; p < current[i].pixels.length; p++) {
        final wasDart = (empty[i].pixels[p] - occupied[i].pixels[p]).abs() > 25;
        final isDart = (empty[i].pixels[p] - current[i].pixels[p]).abs() > 25;
        if (wasDart && !isDart) removed++;
        if (!wasDart && isDart) added++;
      }
      if (before > .0001 &&
          (now < before * .7 ||
              (removed > added * 2 &&
                  removed > before * current[i].pixels.length * .1))) {
        removalViews++;
      }
    }
    if ((dartLimit != null && darts >= dartLimit) ||
        (stable && removalViews >= 2)) {
      waitingForEmpty = true;
    }
    _emptySamples = stable && clearViews == 3 ? _emptySamples + 1 : 0;
    if (_emptySamples >= 3) {
      reset();
      return VisitResetState.cleared;
    }
    return waitingForEmpty
        ? VisitResetState.waitingForEmpty
        : VisitResetState.playing;
  }
}
