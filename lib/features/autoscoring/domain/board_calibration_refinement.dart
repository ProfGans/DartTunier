import 'dart:math';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'board_geometry.dart';

/// Fine alignment from all twenty sector edges and the two coloured rings.
BoardCalibration refineBoardCalibration(
  Uint8List bytes,
  BoardCalibration initial,
) {
  img.Image? decoded;
  try {
    decoded = img.decodeImage(bytes);
  } on RangeError {
    return initial;
  } on FormatException {
    return initial;
  }
  final image = decoded;
  if (image == null) return initial;
  img.Pixel? pixel(double r, double angle) {
    final p = initial.unproject(Point(sin(angle) * r, -cos(angle) * r));
    if (!p.x.isFinite || !p.y.isFinite) return null;
    final x = (p.x * (image.width - 1)).round(),
        y = (p.y * (image.height - 1)).round();
    if (x < 0 || y < 0 || x >= image.width || y >= image.height) return null;
    return image.getPixel(x, y);
  }

  double gray(double r, double a) {
    final p = pixel(r, a);
    return p == null ? 0 : p.r * .299 + p.g * .587 + p.b * .114;
  }

  double edgeScore(double offset) {
    final scores = <double>[];
    for (var sector = 0; sector < 20; sector++) {
      final angle = (sector + .5) * pi / 10 + offset;
      final values = [
        for (final r in [50.0, 70.0, 85.0, 120.0, 140.0, 150.0])
          (gray(r, angle - pi / 180) - gray(r, angle + pi / 180)).abs(),
      ]..sort();
      scores.add((values[2] + values[3]) / 2);
    }
    scores.sort();
    return scores.sublist(4, 16).reduce((a, b) => a + b) / 12;
  }

  var best = edgeScore(0), offset = 0.0;
  for (var step = -50; step <= 50; step++) {
    final candidate = step * pi / 1800;
    final score = edgeScore(candidate);
    if (score > best) {
      best = score;
      offset = candidate;
    }
  }
  if (best < 45 || offset.abs() >= 4.9 * pi / 180) offset = 0;
  bool coloured(img.Pixel? p) =>
      p != null &&
      ((p.r > 30 && p.r > p.g * 1.3 && p.r > p.b * 1.2) ||
          (p.g > 30 && p.g > p.r * 1.2 && p.g > p.b * 1.1));
  double? ring(double centre, double range) {
    final ratios = <double>[];
    for (var sector = 0; sector < 20; sector++) {
      final radii = <double>[];
      for (var r = centre - range; r <= centre + range; r += .5) {
        if (coloured(pixel(r, sector * pi / 10 + offset))) radii.add(r);
      }
      if (radii.length >= 5 && radii.length <= 28) {
        ratios.add(radii.reduce((a, b) => a + b) / radii.length / centre);
      }
    }
    if (ratios.length < 12) return null;
    ratios.sort();
    return ratios[ratios.length ~/ 2];
  }

  final triple = ring(103, 10), doubleRing = ring(166, 12);
  var factor = 1.0;
  if (triple != null &&
      doubleRing != null &&
      (triple - doubleRing).abs() < .015) {
    factor = (triple + doubleRing) / 2;
    if ((factor - 1).abs() > .04) factor = 1;
  }
  final cosine = cos(offset), sine = sin(offset);
  if (offset == 0 && factor == 1) return initial;
  return BoardCalibration([
    for (final q in const [
      Point(0.0, -170.0),
      Point(170.0, 0.0),
      Point(0.0, 170.0),
      Point(-170.0, 0.0),
    ])
      initial.unproject(
        Point(
          (q.x * cosine - q.y * sine) * factor,
          (q.x * sine + q.y * cosine) * factor,
        ),
      ),
  ]);
}
