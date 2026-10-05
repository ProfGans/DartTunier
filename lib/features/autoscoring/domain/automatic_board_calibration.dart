import 'dart:math';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import '../../scorer/domain/x01/x01_rules.dart';
import 'board_geometry.dart';

class CalibrationFailure implements Exception {
  const CalibrationFailure(this.message, {this.diagnostics});
  final String message;
  final BoardDetectionDiagnostics? diagnostics;
  @override
  String toString() => message;
}

/// Image-space observations, including rejected candidates, for camera overlays.
/// These observations never authorize scoring on their own.
class BoardDetectionDiagnostics {
  BoardDetectionDiagnostics({required this.selectiveColors});
  final bool selectiveColors;
  List<BoardPoint> colorSamples = const [];
  List<BoardPoint> bullCandidates = const [];
  BoardOutline? outline;
  int colorCount = 0, doubleBins = 0, tripleBins = 0;
  bool geometryValid = false;
  String stage = 'Farberkennung';
  int get progress => [
    'Farberkennung',
    'Bull-Erkennung',
    'Ring-Suche',
    'Ring-Prüfung',
    'Zahlenring-Ausrichtung',
  ].indexOf(stage);
}

class BoardNumber {
  const BoardNumber(this.value, this.position);
  final int value;

  /// Coordinates on the rectified unit disk, with y pointing down.
  final BoardPoint position;
}

/// Ellipse plus the projected bull resolve perspective, not just an affine oval.
/// A projective disk transform moves the bull to the centre while preserving
/// the outer double circle. Numerals resolve the remaining in-plane rotation.
class BoardOutline {
  BoardOutline(this.center, this.major, this.minor, this.angle, this.bull);
  final BoardPoint center, bull;
  final double major, minor, angle;
  BoardPoint ellipsePoint(BoardPoint image) {
    final d = image - center, c = cos(angle), s = sin(angle);
    return Point((c * d.x + s * d.y) / major, (-s * d.x + c * d.y) / minor);
  }

  BoardPoint imagePoint(BoardPoint ellipse) {
    final x = ellipse.x * major,
        y = ellipse.y * minor,
        c = cos(angle),
        s = sin(angle);
    return center + Point(c * x - s * y, s * x + c * y);
  }

  static BoardPoint _boost(BoardPoint q, BoardPoint b) {
    final b2 = b.x * b.x + b.y * b.y;
    if (b2 < 1e-12) return q;
    if (b2 >= .64) {
      throw const CalibrationFailure(
        'Kamerawinkel zu flach. Board stärker von vorne aufnehmen.',
      );
    }
    final gamma = 1 / sqrt(1 - b2), dot = b.x * q.x + b.y * q.y;
    final denominator = gamma * (1 - dot);
    if (denominator.abs() < 1e-8) {
      throw const CalibrationFailure('Board-Perspektive nicht auflösbar.');
    }
    return (q + b * ((gamma - 1) * dot / b2 - gamma)) * (1 / denominator);
  }

  BoardPoint rectify(BoardPoint image) =>
      _boost(ellipsePoint(image), ellipsePoint(bull));
  BoardPoint unrectify(BoardPoint point) =>
      imagePoint(_boost(point, ellipsePoint(bull) * -1));
}

class AutomaticCalibrationImage {
  const AutomaticCalibrationImage(
    this.outline,
    this.ocrImage, {
    this.diagnostics,
  });
  final BoardOutline outline;
  final Uint8List ocrImage;
  final BoardDetectionDiagnostics? diagnostics;
  static const size = 768;
  static const extent = 1.4;
}

/// Image-only stage, run in an isolate; no platform calls or user markers.
AutomaticCalibrationImage detectBoardOutline(Uint8List bytes) {
  try {
    return _detectBoardOutline(bytes, selectiveColors: true);
  } on CalibrationFailure catch (original) {
    // Start with purer ring colours so a fragmented orange surround cannot
    // pass as a scoring ellipse. Pale rings still get the permissive fallback.
    try {
      return _detectBoardOutline(bytes, selectiveColors: false);
    } on CalibrationFailure catch (alternative) {
      if ((alternative.diagnostics?.progress ?? -1) >
          (original.diagnostics?.progress ?? -1)) {
        rethrow;
      }
      throw original;
    }
  }
}

AutomaticCalibrationImage _detectBoardOutline(
  Uint8List bytes, {
  required bool selectiveColors,
}) {
  final diagnostics = BoardDetectionDiagnostics(
    selectiveColors: selectiveColors,
  );
  try {
    return _prepareBoardImage(bytes, diagnostics);
  } on CalibrationFailure catch (error) {
    throw CalibrationFailure(error.message, diagnostics: diagnostics);
  }
}

AutomaticCalibrationImage _prepareBoardImage(
  Uint8List bytes,
  BoardDetectionDiagnostics diagnostics,
) {
  final selectiveColors = diagnostics.selectiveColors;
  final decoded = img.decodeImage(bytes);
  if (decoded == null) {
    throw const CalibrationFailure('Kamerabild konnte nicht gelesen werden.');
  }
  final source = img.copyResize(decoded, width: 640);
  final all = <BoardPoint>[], red = <BoardPoint>[];
  final redMask = Uint8List(source.width * source.height);
  final colorMask = Uint8List(redMask.length);
  for (var y = 0; y < source.height; y++) {
    for (var x = 0; x < source.width; x++) {
      final p = source.getPixel(x, y);
      if (p.r > 20 && p.r > p.g * 1.25 && p.r > p.b * 1.15) {
        redMask[y * source.width + x] = 1;
      }
      final isRed =
          p.r > 20 &&
          p.r > p.g * (selectiveColors ? 1.35 : 1.25) &&
          p.r > p.b * (selectiveColors ? 1.35 : 1.15);
      final isGreen =
          p.g > 30 &&
          p.g > p.r * 1.2 &&
          p.g > p.b * (selectiveColors ? 1.15 : 1.08);
      if (isRed || isGreen) {
        colorMask[y * source.width + x] = 1;
      }
    }
  }
  // A red surround or coloured wall must not become the outer board contour.
  // Ring segments and the bull are small components; a surround spans a large
  // continuous area. Remove it before estimating covariance or radial bounds.
  final colorVisited = Uint8List(colorMask.length);
  for (var start = 0; start < colorMask.length; start++) {
    if (colorMask[start] == 0 || colorVisited[start] != 0) continue;
    final stack = <int>[start], component = <int>[];
    colorVisited[start] = 1;
    while (stack.isNotEmpty) {
      final index = stack.removeLast();
      component.add(index);
      final x = index % source.width, y = index ~/ source.width;
      for (final next in [
        if (x > 0) index - 1,
        if (x + 1 < source.width) index + 1,
        if (y > 0) index - source.width,
        if (y + 1 < source.height) index + source.width,
      ]) {
        if (colorMask[next] != 0 && colorVisited[next] == 0) {
          colorVisited[next] = 1;
          stack.add(next);
        }
      }
    }
    if (component.length > colorMask.length * .08 ||
        (selectiveColors &&
            component.length > colorMask.length * .001 &&
            component.any(
              (index) =>
                  index % source.width == 0 ||
                  index % source.width == source.width - 1 ||
                  index ~/ source.width == 0 ||
                  index ~/ source.width == source.height - 1,
            ))) {
      for (final index in component) {
        redMask[index] = 0;
      }
      continue;
    }
    for (final index in component) {
      final point = Point(
        (index % source.width) / (source.width - 1),
        (index ~/ source.width) / (source.height - 1),
      );
      all.add(point);
      if (redMask[index] != 0) red.add(point);
    }
  }
  diagnostics.colorCount = all.length;
  final sampleStride = max(1, (all.length / 1200).ceil());
  diagnostics.colorSamples = [
    for (var i = 0; i < all.length; i += sampleStride) all[i],
  ];
  if (all.length < 500 || red.length < 50) {
    throw const CalibrationFailure(
      'Rote und grüne Board-Ringe nicht erkannt. Licht und vollständige Board-Sicht prüfen.',
    );
  }
  diagnostics.stage = 'Bull-Erkennung';
  final mean = _mean(all);
  double xx = 0, xy = 0, yy = 0;
  for (final p in all) {
    final d = p - mean;
    xx += d.x * d.x;
    xy += d.x * d.y;
    yy += d.y * d.y;
  }
  xx /= all.length;
  xy /= all.length;
  yy /= all.length;
  final disc = sqrt(pow(xx - yy, 2) + 4 * xy * xy);
  var outline = BoardOutline(
    mean,
    sqrt((xx + yy + disc) / 2) * 1.6,
    sqrt((xx + yy - disc) / 2) * 1.6,
    .5 * atan2(2 * xy, xx - yy),
    mean,
  );
  if (!outline.minor.isFinite || outline.minor < .025) {
    throw const CalibrationFailure(
      'Board zu klein oder Kamerawinkel zu flach.',
    );
  }
  BoardPoint detectedBull;
  BoardOutline? verifiedOutline;
  try {
    detectedBull = _detectBull(
      source,
      redMask,
      diagnostics,
      coarseOutline: outline,
    );
  } on CalibrationFailure {
    final verified = <(BoardPoint, BoardOutline, BoardDetectionDiagnostics)>[];
    for (final candidate in diagnostics.bullCandidates) {
      final trial = BoardDetectionDiagnostics(selectiveColors: selectiveColors);
      try {
        final rings = _locateBoardRings(outline, candidate, all, trial);
        verified.add((candidate, rings, trial));
      } on CalibrationFailure {
        // A coloured logo is not a bull unless both scoring rings agree.
      }
    }
    if (verified.length != 1) rethrow;
    detectedBull = verified.single.$1;
    verifiedOutline = verified.single.$2;
    diagnostics.doubleBins = verified.single.$3.doubleBins;
    diagnostics.tripleBins = verified.single.$3.tripleBins;
  }
  diagnostics.stage = 'Ring-Suche';
  diagnostics.outline = BoardOutline(
    outline.center,
    outline.major,
    outline.minor,
    outline.angle,
    detectedBull,
  );
  outline =
      verifiedOutline ??
      _locateBoardRings(outline, detectedBull, all, diagnostics);
  diagnostics.outline = outline;
  diagnostics.geometryValid = true;
  diagnostics.stage = 'Zahlenring-Ausrichtung';
  final ocr = img.Image(
    width: AutomaticCalibrationImage.size,
    height: AutomaticCalibrationImage.size,
  );
  img.fill(ocr, color: img.ColorRgb8(255, 255, 255));
  for (var y = 0; y < ocr.height; y++) {
    for (var x = 0; x < ocr.width; x++) {
      final q = Point(
        (x / (ocr.width - 1) * 2 - 1) * AutomaticCalibrationImage.extent,
        (y / (ocr.height - 1) * 2 - 1) * AutomaticCalibrationImage.extent,
      );
      // Hide the board itself so the OCR sees only the number ring.
      if (q.magnitude < 1.025 || q.magnitude > 1.38) continue;
      final p = outline.unrectify(q);
      final sx = p.x * (decoded.width - 1), sy = p.y * (decoded.height - 1);
      if (sx < 0 || sy < 0 || sx >= decoded.width || sy >= decoded.height) {
        continue;
      }
      final color = decoded.getPixelInterpolate(
        sx,
        sy,
        interpolation: img.Interpolation.linear,
      );
      final gray = (color.r * .299 + color.g * .587 + color.b * .114).round();
      ocr.setPixelRgb(x, y, 255 - gray, 255 - gray, 255 - gray);
    }
  }
  return AutomaticCalibrationImage(
    outline,
    img.encodePng(ocr),
    diagnostics: diagnostics,
  );
}

BoardOutline _locateBoardRings(
  BoardOutline initial,
  BoardPoint detectedBull,
  List<BoardPoint> all,
  BoardDetectionDiagnostics diagnostics,
) {
  var bestCoverage = -1;
  CalibrationFailure? failure;
  // Logos may lie outside the scoring rings. Validate several inward contours
  // against both rings before accepting a scoring geometry.
  for (final quantile in [.95, .8, .65, .5]) {
    var outline = initial;
    try {
      for (var pass = 0; pass < 3; pass++) {
        final bins = List.generate(96, (_) => <(double, BoardPoint)>[]);
        final radii = [for (final p in all) outline.ellipsePoint(p).magnitude]
          ..sort();
        final limit = radii[(radii.length * .98).floor()] * 1.06;
        for (final p in all) {
          final q = outline.ellipsePoint(p), r = q.magnitude;
          if (r < .65 || r > limit) continue;
          final bin = ((atan2(q.y, q.x) + pi) / (2 * pi) * 96).floor().clamp(
            0,
            95,
          );
          bins[bin].add((r, p));
        }
        final boundary = <BoardPoint>[];
        for (final bin in bins) {
          if (bin.length < 3) continue;
          bin.sort((a, b) => a.$1.compareTo(b.$1));
          boundary.add(bin[(bin.length * quantile).floor()].$2);
        }
        if (boundary.length < 78) {
          throw const CalibrationFailure(
            'Double-Ring unvollständig. Das gesamte Board muss sichtbar sein.',
          );
        }
        outline = _fitEllipse(boundary, detectedBull);
        outline = BoardOutline(
          outline.center,
          outline.major,
          outline.minor,
          outline.angle,
          detectedBull,
        );
      }
      outline = BoardOutline(
        outline.center,
        outline.major,
        outline.minor,
        outline.angle,
        detectedBull,
      );
      outline = _refineRingGeometry(outline, all);

      diagnostics.stage = 'Ring-Prüfung';
      // Reject coloured backgrounds that happen to fit an oval: both board rings
      // must cover the full circumference at their known physical radius ratio.
      final doubleBins = <int>{}, tripleBins = <int>{};
      for (final p in all) {
        final q = outline.rectify(p), r = q.magnitude;
        final bin = ((atan2(q.y, q.x) + pi) / (2 * pi) * 40).floor().clamp(
          0,
          39,
        );
        if (r > .935 && r < 1.03) doubleBins.add(bin);
        if (r > .565 && r < .65) tripleBins.add(bin);
      }
      bool distributed(Set<int> bins) {
        var gap = 0;
        for (var i = 0; i < 80; i++) {
          gap = bins.contains(i % 40) ? 0 : gap + 1;
          if (gap > 4) return false;
        }
        return true;
      }

      if (doubleBins.length + tripleBins.length > bestCoverage) {
        bestCoverage = doubleBins.length + tripleBins.length;
        diagnostics.outline = outline;
        diagnostics.doubleBins = doubleBins.length;
        diagnostics.tripleBins = tripleBins.length;
      }

      if (doubleBins.length < 26 ||
          tripleBins.length < 30 ||
          !distributed(tripleBins)) {
        throw const CalibrationFailure(
          'Double- und Triple-Ring passen nicht zur Board-Geometrie. Kamerawinkel und freie Sicht prüfen.',
        );
      }
      diagnostics.doubleBins = doubleBins.length;
      diagnostics.tripleBins = tripleBins.length;
      return outline;
    } on CalibrationFailure catch (error) {
      failure = error;
    }
  }
  throw failure!;
}

BoardPoint _mean(List<BoardPoint> points) => Point(
  points.fold<double>(0, (s, p) => s + p.x) / points.length,
  points.fold<double>(0, (s, p) => s + p.y) / points.length,
);

BoardOutline _refineRingGeometry(
  BoardOutline initial,
  List<BoardPoint> colors,
) {
  final candidates = colors.where((p) {
    final r = initial.rectify(p).magnitude;
    return (r - .976).abs() < .08 || (r - 103 / 170).abs() < .08;
  }).toList();
  if (candidates.length < 100) return initial;
  final stride = max(1, (candidates.length / 1200).ceil());
  final points = [
    for (var i = 0; i < candidates.length; i += stride) candidates[i],
  ];
  BoardOutline build(List<double> p) =>
      BoardOutline(Point(p[0], p[1]), p[2], p[3], p[4], initial.bull);
  double loss(BoardOutline outline) {
    if (outline.ellipsePoint(initial.bull).magnitude > .45 ||
        outline.minor < .025 ||
        outline.major < .025) {
      return double.infinity;
    }
    var sum = 0.0;
    for (final p in points) {
      final r = outline.rectify(p).magnitude;
      final residual = min((r - .976).abs(), (r - 103 / 170).abs());
      sum += min(residual * residual, .05 * .05);
    }
    return sum / points.length;
  }

  var params = [
    initial.center.x,
    initial.center.y,
    initial.major,
    initial.minor,
    initial.angle,
  ];
  var best = loss(initial);
  for (var pass = 0; pass < 30; pass++) {
    final scale = pass < 10
        ? 1.0
        : pass < 20
        ? .5
        : .25;
    for (var axis = 0; axis < 5; axis++) {
      for (final sign in [-1, 1]) {
        final next = List<double>.of(params);
        next[axis] += sign * scale * (axis == 4 ? .015 : .003);
        final score = loss(build(next));
        if (score < best) {
          best = score;
          params = next;
        }
      }
    }
  }
  return build(params);
}

BoardPoint _detectBull(
  img.Image source,
  Uint8List mask,
  BoardDetectionDiagnostics diagnostics, {
  required BoardOutline coarseOutline,
}) {
  final visited = Uint8List(mask.length), candidates = <BoardPoint>[];
  for (var start = 0; start < mask.length; start++) {
    if (mask[start] == 0 || visited[start] != 0) continue;
    final stack = [start], component = <BoardPoint>[];
    visited[start] = 1;
    var minX = source.width, maxX = 0, minY = source.height, maxY = 0;
    while (stack.isNotEmpty) {
      final index = stack.removeLast(),
          x = index % source.width,
          y = index ~/ source.width;
      minX = min(minX, x);
      maxX = max(maxX, x);
      minY = min(minY, y);
      maxY = max(maxY, y);
      component.add(Point(x / (source.width - 1), y / (source.height - 1)));
      for (final next in [
        if (x > 0) index - 1,
        if (x + 1 < source.width) index + 1,
        if (y > 0) index - source.width,
        if (y + 1 < source.height) index + source.width,
      ]) {
        if (mask[next] != 0 && visited[next] == 0) {
          visited[next] = 1;
          stack.add(next);
        }
      }
    }
    if (component.length < 4) continue;
    final center = _mean(component);
    final rx = (maxX - minX + 1) / 2, ry = (maxY - minY + 1) / 2;
    if (center.x < .2 ||
        center.x > .8 ||
        center.y < .2 ||
        center.y > .8 ||
        rx < 1 ||
        ry < 1 ||
        rx > source.width * .025 ||
        ry > source.height * .025) {
      continue;
    }
    var green = 0;
    for (final radius in [1.5, 1.8, 2.1]) {
      var support = 0;
      for (var i = 0; i < 24; i++) {
        final x =
            (center.x * (source.width - 1) + cos(i * pi / 12) * rx * radius)
                .round();
        final y =
            (center.y * (source.height - 1) + sin(i * pi / 12) * ry * radius)
                .round();
        if (x < 0 || y < 0 || x >= source.width || y >= source.height) continue;
        final p = source.getPixel(x, y);
        if (p.g > 30 && p.g > p.r * 1.2 && p.g > p.b * 1.08) support++;
      }
      green = max(green, support);
    }
    if (green >= 10) candidates.add(center);
  }
  diagnostics.bullCandidates = candidates;
  if (candidates.length == 1) return candidates.single;
  final ranked = candidates.toList()
    ..sort(
      (a, b) => coarseOutline
          .ellipsePoint(a)
          .magnitude
          .compareTo(coarseOutline.ellipsePoint(b).magnitude),
    );
  if (ranked.length > 1) {
    final nearest = coarseOutline.ellipsePoint(ranked.first).magnitude;
    final next = coarseOutline.ellipsePoint(ranked[1]).magnitude;
    // Prefer a clearly central bull even when the coarse ellipse also places
    // a logo inside its broad central region. Close contenders stay ambiguous.
    if (nearest < .35 && next - nearest > .18 && next > nearest * 2) {
      return ranked.first;
    }
  }
  final central = candidates
      .where((p) => coarseOutline.ellipsePoint(p).magnitude < .55)
      .toList();
  if (central.length != 1) {
    throw const CalibrationFailure(
      'Bull nicht eindeutig erkannt. Board leeren und Beleuchtung prüfen.',
    );
  }
  return central.single;
}

BoardOutline _fitEllipse(List<BoardPoint> points, BoardPoint bull) {
  BoardOutline? best;
  var bestInliers = <BoardPoint>[];
  final random = Random(2718);
  for (var attempt = 0; attempt < 600; attempt++) {
    try {
      final sample = attempt == 0
          ? points
          : [for (var i = 0; i < 6; i++) points[random.nextInt(points.length)]];
      final candidate = _solveEllipse(sample);
      if (candidate.ellipsePoint(bull).magnitude > .45) continue;
      final inliers = points
          .where((p) => (candidate.ellipsePoint(p).magnitude - 1).abs() < .035)
          .toList();
      if (inliers.length > bestInliers.length) {
        best = candidate;
        bestInliers = inliers;
      }
    } on CalibrationFailure {
      continue;
    }
  }
  if (best == null || bestInliers.length < points.length * .5) {
    throw const CalibrationFailure(
      'Double-Ring zu stark verdeckt oder verzerrt.',
    );
  }
  final refined = _solveEllipse(bestInliers);
  return refined.ellipsePoint(bull).magnitude <= .45 ? refined : best;
}

BoardOutline _solveEllipse(List<BoardPoint> points) {
  final mean = _mean(points),
      matrix = List.generate(5, (_) => List.filled(6, 0.0));
  for (final p in points) {
    final d = p - mean, row = [d.x * d.x, d.x * d.y, d.y * d.y, d.x, d.y];
    for (var i = 0; i < 5; i++) {
      for (var j = 0; j < 5; j++) {
        matrix[i][j] += row[i] * row[j];
      }
      matrix[i][5] += row[i];
    }
  }
  for (var col = 0; col < 5; col++) {
    var pivot = col;
    for (var r = col + 1; r < 5; r++) {
      if (matrix[r][col].abs() > matrix[pivot][col].abs()) pivot = r;
    }
    final swap = matrix[col];
    matrix[col] = matrix[pivot];
    matrix[pivot] = swap;
    final divisor = matrix[col][col];
    if (divisor.abs() < 1e-12) {
      throw const CalibrationFailure('Board-Ellipse nicht eindeutig.');
    }
    for (var j = col; j < 6; j++) {
      matrix[col][j] /= divisor;
    }
    for (var r = 0; r < 5; r++) {
      if (r == col) continue;
      final factor = matrix[r][col];
      for (var j = col; j < 6; j++) {
        matrix[r][j] -= factor * matrix[col][j];
      }
    }
  }
  final a = matrix[0][5],
      b = matrix[1][5] / 2,
      c = matrix[2][5],
      d = matrix[3][5] / 2,
      e = matrix[4][5];
  final det = a * c - b * b;
  if (det <= 0 || a <= 0 || c <= 0) {
    throw const CalibrationFailure('Erkannte Kontur ist keine Board-Ellipse.');
  }
  final offset = Point((b * e - c * d) / det, (b * d - a * e) / det),
      center = mean + offset;
  final k =
      1 +
      a * offset.x * offset.x +
      2 * b * offset.x * offset.y +
      c * offset.y * offset.y;
  final disc = sqrt(pow(a - c, 2) + 4 * b * b),
      small = (a + c - disc) / 2,
      large = (a + c + disc) / 2;
  final major = sqrt(k / small),
      minor = sqrt(k / large),
      angle = .5 * atan2(2 * b, a - c) + pi / 2;
  if (!major.isFinite ||
      !minor.isFinite ||
      minor < .025 ||
      major > 1.0 ||
      minor / major < .15) {
    throw const CalibrationFailure('Board-Größe oder Perspektive ungeeignet.');
  }
  final result = BoardOutline(center, major, minor, angle, center);
  return result;
}

class AutomaticCalibrationResult {
  const AutomaticCalibrationResult(
    this.calibration,
    this.numberCount, {
    this.diagnostics,
    this.quality = const {},
  });
  final BoardCalibration calibration;
  final int numberCount;
  final Map<String, Object?> quality;
  final BoardDetectionDiagnostics? diagnostics;
}

AutomaticCalibrationResult resolveBoardOrientation(
  BoardOutline outline,
  List<BoardNumber> numbers, {
  BoardDetectionDiagnostics? diagnostics,
}) {
  final candidates = <(double, int)>[];
  for (final number in numbers) {
    final index = X01Rules.wheel.indexOf(number.value),
        radius = number.position.magnitude;
    if (index < 0 || radius < 1.04 || radius > 1.38) continue;
    candidates.add((
      atan2(number.position.x, -number.position.y) - index * pi / 10,
      number.value,
    ));
  }
  double angularDistance(double a, double b) =>
      atan2(sin(a - b), cos(a - b)).abs();
  var best = <(double, int)>[];
  for (final candidate in candidates) {
    final unique = <int, (double, int)>{};
    for (final other in candidates) {
      if (angularDistance(candidate.$1, other.$1) < pi / 30) {
        unique[other.$2] = other;
      }
    }
    if (unique.length > best.length) best = unique.values.toList();
  }
  if (best.length < 3) {
    throw CalibrationFailure(
      'Mindestens drei Board-Zahlen müssen lesbar sein. Zahlenring vollständig zeigen, Kamera scharfstellen und Licht prüfen.',
      diagnostics: diagnostics,
    );
  }
  final angle = atan2(
    best.fold<double>(0, (s, p) => s + sin(p.$1)),
    best.fold<double>(0, (s, p) => s + cos(p.$1)),
  );
  // A competing rotation with comparable support is ambiguous (e.g. 6 / 9).
  for (final candidate in candidates) {
    if (angularDistance(candidate.$1, angle) < pi / 20) continue;
    final support = candidates
        .where((p) => angularDistance(p.$1, candidate.$1) < pi / 30)
        .map((p) => p.$2)
        .toSet()
        .length;
    if (support >= 3 && support >= best.length - 1) {
      throw CalibrationFailure(
        'Segmentausrichtung nicht eindeutig. Zahlenring schärfer aufnehmen.',
        diagnostics: diagnostics,
      );
    }
  }
  final points = [
    for (var i = 0; i < 4; i++)
      outline.unrectify(
        Point(sin(angle + i * pi / 2), -cos(angle + i * pi / 2)),
      ),
  ];
  return AutomaticCalibrationResult(
    BoardCalibration(points),
    best.length,
    diagnostics: diagnostics,
  );
}
