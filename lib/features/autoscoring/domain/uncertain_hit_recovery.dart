import 'dart:math';
import 'board_geometry.dart';
import 'board_frame_alignment.dart';
import 'frame_detector.dart';

class RecoveredHit {
  const RecoveredHit(this.hit, this.axes);
  final FusedHit hit;
  final List<DartAxis?> axes;
}

class _Hypothesis {
  const _Hypothesis(
    this.point,
    this.axes,
    this.pair,
    this.quality,
    this.thirdSupport,
  );
  final BoardPoint point;
  final List<DartAxis?> axes;
  final (int, int) pair;
  final double quality;
  final int thirdSupport;
}

/// Restricted recovery for a weak outside miss or grossly inconsistent fit.
/// Uses actual capture timestamps, one line per camera, new pixel support in
/// the remaining camera and agreement on two distinct frames. No target labels.
class UncertainHitRecovery {
  List<GrayFrame> _references = [];
  _Hypothesis? _previous;
  int? _previousTime, _startTime;
  List<int>? _previousCaptureTimes;
  Map<String, Object?> metrics = const {};
  void reset() {
    _references = [];
    _previous = null;
    _previousTime = _startTime = null;
    _previousCaptureTimes = null;
  }

  RecoveredHit? observe(
    FusedHit provisional,
    List<GrayFrame> before,
    List<GrayFrame> empty,
    List<GrayFrame> current,
    List<BoardCalibration> calibrations,
    List<List<DartAxis>> candidates,
  ) {
    final axes = candidates
        .where((c) => c.isNotEmpty)
        .map((c) => c.first)
        .toList();
    final weakOutside =
        provisional.point.magnitude > 170 &&
        axes.any((a) => a.confidence < .85);
    final contradictoryViews =
        axes.length == 3 && axes.any((a) => a.distance(provisional.point) > 20);
    if (!provisional.needsReview ||
        (!weakOutside && !contradictoryViews && provisional.residual <= 8) ||
        current.length != 3 ||
        before.length != 3 ||
        empty.length != 3 ||
        calibrations.length != 3 ||
        candidates.length != 3 ||
        current.any((f) => f.timestampUs == null) ||
        List.generate(
          3,
          (i) =>
              before[i].width != current[i].width ||
              before[i].height != current[i].height ||
              empty[i].width != current[i].width ||
              empty[i].height != current[i].height,
        ).any((v) => v)) {
      reset();
      metrics = const {'eligible': false};
      return null;
    }
    if (_references.length != 3 ||
        List.generate(
          3,
          (i) => !identical(_references[i], before[i]),
        ).any((v) => v)) {
      reset();
      _references = List.of(before);
    }
    final now = current.map((f) => f.timestampUs!).reduce(max);
    if (_previousTime != null && now <= _previousTime!) return null;
    if (_previousCaptureTimes != null &&
        List.generate(
          3,
          (i) => current[i].timestampUs! <= _previousCaptureTimes![i],
        ).any((v) => v)) {
      return null;
    }
    _startTime ??= now;
    if (now - _startTime! > 180000) {
      metrics = const {'eligible': true, 'expired': true};
      return null;
    }
    final watch = Stopwatch()..start();
    final aligned = [
      for (var i = 0; i < 3; i++)
        alignBoardFrame(before[i], current[i], empty[i], calibrations[i]),
    ];
    final options = [
      for (var i = 0; i < 3; i++)
        aligned[i].applied
            ? const FrameDetector().candidates(
                before[i],
                aligned[i].frame,
                calibrations[i],
              )
            : candidates[i],
    ];
    final hypotheses = <_Hypothesis>[];
    final rejected = <Map<String, Object?>>[];
    for (var i = 0; i < 3; i++) {
      for (var j = i + 1; j < 3; j++) {
        final third = 3 - i - j;
        for (final a in options[i]) {
          for (final b in options[j]) {
            if (min(a.confidence, b.confidence) < .65 ||
                max(a.confidence, b.confidence) < .8 ||
                (a.a * b.b - a.b * b.a).abs() < .25) {
              continue;
            }
            final hit = decideAxes([a, b]);
            if (hit == null || hit.point.magnitude > 160) continue;
            final support = _localNewSupport(
              hit.point,
              before[third],
              aligned[third].frame,
              empty[third],
              calibrations[third],
            );

            // Both selected lines must also include connected new shaft pixels,
            // discounting changed pixels already occupied by an earlier dart.
            final firstNovelty = _shaftNovelty(
              a,
              before[i],
              aligned[i].frame,
              empty[i],
              calibrations[i],
            );
            final secondNovelty = _shaftNovelty(
              b,
              before[j],
              aligned[j].frame,
              empty[j],
              calibrations[j],
            );
            if (support < 3 || firstNovelty < 6 || secondNovelty < 6) {
              rejected.add({
                'pair': [i, j],
                'x': hit.point.x,
                'y': hit.point.y,
                'support': support,
                'shaftPixels': [firstNovelty, secondNovelty],
              });
              continue;
            }
            hypotheses.add(
              _Hypothesis(
                hit.point,
                [
                  for (var k = 0; k < 3; k++)
                    k == i
                        ? a
                        : k == j
                        ? b
                        : null,
                ],
                (i, j),
                a.confidence + b.confidence + min(support, 12) * .01,
                support,
              ),
            );
          }
        }
      }
    }
    hypotheses.sort((a, b) => b.quality.compareTo(a.quality));
    final best = hypotheses.isEmpty ? null : hypotheses.first;
    final ambiguous =
        best != null &&
        hypotheses
            .skip(1)
            .any(
              (h) =>
                  best.quality - h.quality < .08 &&
                  h.point.distanceTo(best.point) > 5,
            );
    final confirmed =
        best != null &&
        !ambiguous &&
        _previous != null &&
        _previous!.pair == best.pair &&
        List.generate(3, (i) {
          final a = best.axes[i], b = _previous!.axes[i];
          return a == null && b == null ||
              a != null && b != null && (a.a * b.b - a.b * b.a).abs() <= .04;
        }).every((stable) => stable) &&
        best.point.distanceTo(_previous!.point) <= 3 &&
        BoardGeometry.score(best.point).label ==
            BoardGeometry.score(_previous!.point).label &&
        now - _previousTime! <= 100000;
    metrics = {
      'eligible': true,
      'hypotheses': hypotheses.length,
      'rejected': rejected,
      'ambiguous': ambiguous,
      'confirmed': confirmed,
      'timestampMicroseconds': now,
      'alignment': aligned.map((a) => a.toJson()).toList(),
      'processingMilliseconds': watch.elapsedMicroseconds / 1000,
      'candidate': best == null
          ? null
          : {
              'xMillimetres': best.point.x,
              'yMillimetres': best.point.y,
              'thirdCameraNewPixels': best.thirdSupport,
            },
    };
    _previous = ambiguous ? null : best;
    _previousTime = now;
    _previousCaptureTimes = current.map((f) => f.timestampUs!).toList();
    return confirmed
        ? RecoveredHit(
            FusedHit(best.point, 0, 2, forcedDecision: true),
            best.axes,
          )
        : null;
  }
}

int _localNewSupport(
  BoardPoint point,
  GrayFrame before,
  GrayFrame after,
  GrayFrame empty,
  BoardCalibration calibration,
) {
  final image = calibration.unproject(point);
  final bounds = [
    for (var i = 0; i < 12; i++)
      calibration.unproject(
        point + Point(sin(i * pi / 6) * 6, cos(i * pi / 6) * 6),
      ),
  ];
  final left = max(
    1,
    (bounds.map((p) => p.x).reduce(min) * after.width).floor(),
  );
  final right = min(
    after.width - 2,
    (bounds.map((p) => p.x).reduce(max) * after.width).ceil(),
  );
  final top = max(
    1,
    (bounds.map((p) => p.y).reduce(min) * after.height).floor(),
  );
  final bottom = min(
    after.height - 2,
    (bounds.map((p) => p.y).reduce(max) * after.height).ceil(),
  );
  if (!image.x.isFinite || !image.y.isFinite) return 0;
  var support = 0;
  for (var y = top; y <= bottom; y++) {
    for (var x = left; x <= right; x++) {
      if (!_newPixel(before, after, empty, x, y)) continue;
      if (calibration
              .project(Point(x / (after.width - 1), y / (after.height - 1)))
              .distanceTo(point) <=
          6) {
        support++;
      }
    }
  }
  return support;
}

int _shaftNovelty(
  DartAxis axis,
  GrayFrame before,
  GrayFrame after,
  GrayFrame empty,
  BoardCalibration calibration,
) {
  var support = 0;
  for (var y = 1; y < after.height - 1; y += 2) {
    for (var x = 1; x < after.width - 1; x += 2) {
      if (!_newPixel(before, after, empty, x, y)) continue;
      final point = calibration.project(
        Point(x / (after.width - 1), y / (after.height - 1)),
      );
      if (point.magnitude <= 230 && axis.distance(point) < 3) support++;
      if (support >= 12) return support;
    }
  }
  return support;
}

bool _newPixel(
  GrayFrame before,
  GrayFrame after,
  GrayFrame empty,
  int x,
  int y,
) {
  final i = y * after.width + x;
  if ((after.pixels[i] - before.pixels[i]).abs() < 24 ||
      (after.pixels[i] - empty.pixels[i]).abs() <
          (before.pixels[i] - empty.pixels[i]).abs() + 8) {
    return false;
  }
  var neighbours = 0;
  for (var dy = -1; dy <= 1; dy++) {
    for (var dx = -1; dx <= 1; dx++) {
      final p = (y + dy) * after.width + x + dx;
      if ((after.pixels[p] - before.pixels[p]).abs() >= 24) neighbours++;
    }
  }
  return neighbours >= 3;
}
