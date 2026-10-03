import 'dart:math';
import 'frame_detector.dart';
import 'board_geometry.dart';

enum VisitResetState { playing, waitingForEmpty, cleared }

/// Compare against both the original empty board and the last counted darts.
/// A partial removal must never be interpreted as another thrown dart.
class AutomaticVisitReset {
  bool waitingForEmpty = false;
  int _emptySamples = 0;
  int _settledSamples = 0;
  List<GrayFrame>? _previous;
  List<List<int>>? _regions;
  List<BoardCalibration>? _calibrations;
  List<Map<String, Object>> cameraMetrics = [];

  void reset() {
    waitingForEmpty = false;
    _emptySamples = 0;
    _settledSamples = 0;
    _previous = null;
    _regions = null;
    _calibrations = null;
    cameraMetrics = [];
  }

  VisitResetState observe({
    required List<GrayFrame> empty,
    required List<GrayFrame> occupied,
    required List<GrayFrame> current,
    required bool stable,
    required int darts,
    int? dartLimit = 3,
    List<BoardCalibration>? calibrations,
  }) {
    if (darts == 0) return VisitResetState.playing;
    if (_regions == null ||
        (_calibrations == null && calibrations != null) ||
        (calibrations != null &&
            List.generate(
              3,
              (i) => !identical(_calibrations![i], calibrations[i]),
            ).any((changed) => changed))) {
      _calibrations = calibrations == null ? null : List.of(calibrations);
      _regions = List.generate(
        3,
        (i) => [
          for (var p = 0; p < current[i].pixels.length; p++)
            if (calibrations == null ||
                calibrations[i]
                        .project(
                          Point(
                            (p % current[i].width) / (current[i].width - 1),
                            (p ~/ current[i].width) / (current[i].height - 1),
                          ),
                        )
                        .magnitude <=
                    BoardGeometry.detectionRadius)
              p,
        ],
      );
    }
    final settled =
        _previous != null &&
        List.generate(
          3,
          (i) =>
              _changed(_previous![i], current[i], _regions![i]) /
                  max(1, _regions![i].length) <
              .002,
        ).every((value) => value);
    _previous = List.of(current);
    _settledSamples = settled ? _settledSamples + 1 : 0;
    final quiet = stable || _settledSamples >= 2;
    final occupiedCounts = List.generate(
      3,
      (i) => _changed(empty[i], occupied[i], _regions![i]),
    );
    // A bounce leaves no dart behind; an already empty board is not removal.
    if (occupiedCounts.where((count) => count >= 6).length < 2) {
      return VisitResetState.playing;
    }
    var clearViews = 0, removalViews = 0;
    cameraMetrics = [];
    for (var i = 0; i < 3; i++) {
      final before = occupiedCounts[i];
      final beforeOffset = _exposure(empty[i], occupied[i], _regions![i]);
      final nowOffset = _exposure(empty[i], current[i], _regions![i]);
      var removed = 0, added = 0, retained = 0;
      for (final p in _regions![i]) {
        final wasDart =
            (occupied[i].pixels[p] -
                    (empty[i].pixels[p] * beforeOffset.$1 + beforeOffset.$2))
                .abs() >
            25;
        final isDart =
            (current[i].pixels[p] -
                    (empty[i].pixels[p] * nowOffset.$1 + nowOffset.$2))
                .abs() >
            25;
        if (wasDart && !isDart) removed++;
        if (!wasDart && isDart) added++;
        if (wasDart && isDart) retained++;
      }
      final now = retained + added;
      cameraMetrics.add({
        'before': before,
        'now': now,
        'retained': retained,
        'added': added,
        'removed': removed,
        'regionPixels': _regions![i].length,
      });
      final tolerance = max(
        2.0,
        before * .12,
      ).clamp(2, max(2, _regions![i].length * .0005));
      // Small unrelated noise must not keep an otherwise cleared board locked.
      // A remaining shaft still overlaps the occupied reference and vetoes clear.
      final viewClear =
          now <= tolerance ||
          (before >= 6 &&
              retained <= max(2, before * .08) &&
              added <= max(3, before * .25));
      cameraMetrics[i]['clear'] = viewClear;
      if (viewClear) {
        clearViews++;
      }
      if (before >= 6 &&
          (now < before * .7 ||
              (removed > added * 2 && removed > before * .1))) {
        removalViews++;
      }
    }
    // Enter removal mode as soon as two cameras see darts disappear. Waiting
    // for all views to settle can otherwise score the removal as a new dart
    // during an unfinished visit (one or two counted throws).
    if ((dartLimit != null && darts >= dartLimit) || removalViews >= 2) {
      waitingForEmpty = true;
    }
    // Two independently empty views can release one view with small residual
    // board texture, but only after substantial removal and without a shaft.
    var residualRecovery = false;
    if (quiet && clearViews == 2 && calibrations != null) {
      for (var i = 0; i < 3; i++) {
        final metrics = cameraMetrics[i];
        if (metrics['clear'] == true) continue;
        final before = metrics['before'] as int;
        final now = metrics['now'] as int;
        final retained = metrics['retained'] as int;
        final added = metrics['added'] as int;
        if (before >= 6 &&
            now >
                max(
                  2,
                  before * .12,
                ).clamp(2, max(2, _regions![i].length * .0005)) &&
            ((now < before * .3 &&
                    now <= _regions![i].length * .005 &&
                    retained < before * .3 &&
                    added <= max(3, _regions![i].length * .0005)) ||
                // Changed board texture after exposure settles may be new,
                // rather than retained. Require almost all old dart pixels
                // to disappear and bound the total unexplained image area.
                (retained <= max(2, before * .03) &&
                    now < before * .7 &&
                    now <= _regions![i].length * .015)) &&
            const FrameDetector().axis(empty[i], current[i], calibrations[i]) ==
                null) {
          residualRecovery = true;
          metrics['residualRecovery'] = true;
          clearViews = 3;
          break;
        }
      }
    }
    _emptySamples = quiet && clearViews == 3 ? _emptySamples + 1 : 0;
    if (_emptySamples >= (residualRecovery ? 6 : 3)) {
      reset();
      return VisitResetState.cleared;
    }
    return waitingForEmpty
        ? VisitResetState.waitingForEmpty
        : VisitResetState.playing;
  }

  // Median changes per intensity band reject sparse darts and noise. Fit the
  // dark and light board areas to compensate contrast as well as brightness.
  (double, double) _exposure(
    GrayFrame reference,
    GrayFrame current,
    List<int> region,
  ) {
    final bands = List.generate(16, (_) => <int>[]);
    final all = <int>[];
    for (var n = 0; n < region.length; n += 8) {
      final i = region[n];
      final delta = current.pixels[i] - reference.pixels[i];
      bands[reference.pixels[i] ~/ 16].add(delta);
      all.add(delta);
    }
    if (all.isEmpty) return (1, 0);
    all.sort();
    final offset = all[all.length ~/ 2].toDouble();
    var count = 0;
    var sx = 0.0, sy = 0.0, sxx = 0.0, sxy = 0.0;
    for (var b = 0; b < bands.length; b++) {
      final values = bands[b];
      if (values.length < 12) continue;
      values.sort();
      final x = b * 16 + 7.5;
      final y = values[values.length ~/ 2].toDouble();
      count++;
      sx += x;
      sy += y;
      sxx += x * x;
      sxy += x * y;
    }
    if (count >= 3 && sxx - sx * sx / count > 1000) {
      final slope = (sxy - sx * sy / count) / (sxx - sx * sx / count);
      final intercept = (sy - slope * sx) / count;
      if (slope.abs() <= .4 && intercept.abs() <= 60) {
        return (1 + slope, intercept);
      }
    }
    return (1, offset.abs() <= 60 ? offset : 0);
  }

  int _changed(GrayFrame reference, GrayFrame current, List<int> region) {
    final exposure = _exposure(reference, current, region);
    var count = 0;
    for (final i in region) {
      if ((current.pixels[i] -
                  (reference.pixels[i] * exposure.$1 + exposure.$2))
              .abs() >
          25) {
        count++;
      }
    }
    return count;
  }
}
