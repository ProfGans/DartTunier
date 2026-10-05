import 'dart:math';
import '../domain/frame_detector.dart';

/// Computed during export, not in the live recognition loop.
Map<String, Object?> diagnosticImageQuality(GrayFrame frame) {
  var count = 0, dark = 0, bright = 0;
  var sum = 0.0, edgeSum = 0.0, edgeSquares = 0.0;
  for (var y = 1; y < frame.height - 1; y += 2) {
    for (var x = 1; x < frame.width - 1; x += 2) {
      final i = y * frame.width + x, v = frame.pixels[i];
      if (v <= 5) dark++;
      if (v >= 250) bright++;
      final edge =
          4 * v -
          frame.pixels[i - 1] -
          frame.pixels[i + 1] -
          frame.pixels[i - frame.width] -
          frame.pixels[i + frame.width];
      count++;
      sum += v;
      edgeSum += edge;
      edgeSquares += edge * edge;
    }
  }
  return {
    'width': frame.width,
    'height': frame.height,
    'sampledPixels': count,
    'meanLuminance': count == 0 ? null : sum / count,
    'darkClippingFraction': count == 0 ? null : dark / count,
    'brightClippingFraction': count == 0 ? null : bright / count,
    'laplacianVariance': count == 0
        ? null
        : max(0, edgeSquares / count - pow(edgeSum / count, 2)),
    'interpretation':
        'Whole-frame quality proxies; not an autofocus or board-only sharpness measurement.',
  };
}

Map<String, Object?> diagnosticCaptureCadence(
  List<int?> timestamps,
  List<int?> sequences,
) {
  final deltas = <int>[];
  var repeated = 0, nonmonotonic = 0, gaps = 0;
  for (var i = 1; i < timestamps.length; i++) {
    final a = timestamps[i - 1], b = timestamps[i];
    if (a == null || b == null) continue;
    if (b == a) {
      repeated++;
    } else if (b < a) {
      nonmonotonic++;
    } else {
      deltas.add(b - a);
    }
  }
  for (var i = 1; i < sequences.length; i++) {
    final a = sequences[i - 1], b = sequences[i];
    if (a != null && b != null && b > a + 1) gaps += b - a - 1;
  }
  final ordered = List<int>.of(deltas)..sort();
  return {
    'savedFrames': timestamps.length,
    'positiveIntervals': deltas.length,
    'medianHostIntervalMilliseconds': ordered.isEmpty
        ? null
        : ordered[ordered.length ~/ 2] / 1000,
    'maximumHostIntervalMilliseconds': ordered.isEmpty
        ? null
        : ordered.last / 1000,
    'repeatedTimestamps': repeated,
    'nonmonotonicTimestamps': nonmonotonic,
    'sequenceGaps': gaps,
    'interpretation':
        'Saved host-arrival intervals, not hardware camera FPS; sequence gaps can include sampling or discarded captures.',
  };
}
