import 'dart:math';
import 'dart:typed_data';
import 'board_geometry.dart';
import 'frame_detector.dart';

class BoardFrameAlignment {
  const BoardFrameAlignment(
    this.frame,
    this.dx,
    this.dy,
    this.improvement,
    this.samples,
  );
  final GrayFrame frame;
  final double dx, dy, improvement;
  final int samples;
  bool get applied => dx != 0 || dy != 0;
  Map<String, Object?> toJson() => {
    'dxPixels': dx,
    'dyPixels': dy,
    'relativeErrorReduction': improvement,
    'samples': samples,
    'applied': applied,
  };
}

/// Align only a secondary analysis to its occupied reference. Static ring
/// edges provide registration; pixels occupied by prior darts are excluded.
/// Primary scoring, camera previews and calibration are never moved.
BoardFrameAlignment alignBoardFrame(
  GrayFrame reference,
  GrayFrame current,
  GrayFrame empty,
  BoardCalibration calibration,
) {
  BoardFrameAlignment unchanged([int samples = 0]) =>
      BoardFrameAlignment(current, 0, 0, 0, samples);
  if (reference.width != current.width ||
      reference.height != current.height ||
      empty.width != reference.width ||
      empty.height != reference.height) {
    return unchanged();
  }
  final samples = <(int, int)>[];
  for (var y = 3; y < reference.height - 3; y += 3) {
    for (var x = 3; x < reference.width - 3; x += 3) {
      final i = y * reference.width + x;
      if ((reference.pixels[i] - empty.pixels[i]).abs() > 18) continue;
      final gradient =
          (reference.pixels[i + 1] - reference.pixels[i - 1]).abs() +
          (reference.pixels[i + reference.width] -
                  reference.pixels[i - reference.width])
              .abs();
      if (gradient < 35) continue;
      final p = calibration.project(
        Point(x / (reference.width - 1), y / (reference.height - 1)),
      );
      if (p.magnitude >= 175 && p.magnitude <= 225) samples.add((x, y));
    }
  }
  if (samples.length < 40) return unchanged(samples.length);
  final stride = max(1, (samples.length / 600).ceil());
  final selected = [
    for (var i = 0; i < samples.length; i += stride) samples[i],
  ];
  double cost(double dx, double dy) =>
      selected.fold<double>(
        0,
        (sum, p) =>
            sum +
            min(
              30,
              (reference.pixels[p.$2 * reference.width + p.$1] -
                      _sample(current, p.$1 + dx, p.$2 + dy))
                  .abs(),
            ),
      ) /
      selected.length;
  final baseline = cost(0, 0);
  if (baseline < 1.5) return unchanged(selected.length);
  var best = baseline, dx = 0.0, dy = 0.0;
  for (var y = -1.5; y <= 1.5; y += .5) {
    for (var x = -1.5; x <= 1.5; x += .5) {
      final value = cost(x, y);
      if (value < best) {
        best = value;
        dx = x;
        dy = y;
      }
    }
  }
  final coarseX = dx, coarseY = dy;
  for (var y = coarseY - .375; y <= coarseY + .375; y += .125) {
    for (var x = coarseX - .375; x <= coarseX + .375; x += .125) {
      if (x.abs() > 1.5 || y.abs() > 1.5) continue;
      final value = cost(x, y);
      if (value < best) {
        best = value;
        dx = x;
        dy = y;
      }
    }
  }
  final gain = (baseline - best) / baseline;
  if (gain < .15 || sqrt(dx * dx + dy * dy) < .125) {
    return unchanged(selected.length);
  }
  return BoardFrameAlignment(
    _shift(current, dx, dy),
    dx,
    dy,
    gain,
    selected.length,
  );
}

double _sample(GrayFrame frame, double x, double y) {
  x = x.clamp(0, frame.width - 1).toDouble();
  y = y.clamp(0, frame.height - 1).toDouble();
  final ix = x.floor(), iy = y.floor(), tx = x - ix, ty = y - iy;
  final nextX = min(ix + 1, frame.width - 1),
      nextY = min(iy + 1, frame.height - 1);
  final a =
      frame.pixels[iy * frame.width + ix] * (1 - tx) +
      frame.pixels[iy * frame.width + nextX] * tx;
  final b =
      frame.pixels[nextY * frame.width + ix] * (1 - tx) +
      frame.pixels[nextY * frame.width + nextX] * tx;
  return a * (1 - ty) + b * ty;
}

GrayFrame _shift(GrayFrame frame, double dx, double dy) {
  final pixels = Uint8List(frame.pixels.length);
  for (var y = 0; y < frame.height; y++) {
    for (var x = 0; x < frame.width; x++) {
      pixels[y * frame.width + x] = _sample(frame, x + dx, y + dy).round();
    }
  }
  final detail = frame.detail;
  return GrayFrame(
    frame.width,
    frame.height,
    pixels,
    detail: detail == null
        ? null
        : _shift(
            detail,
            dx * (detail.width - 1) / (frame.width - 1),
            dy * (detail.height - 1) / (frame.height - 1),
          ),
    sourceAspectRatio: frame.sourceAspectRatio,
    timestampUs: frame.timestampUs,
    sequence: frame.sequence,
  );
}
