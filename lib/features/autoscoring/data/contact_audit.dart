import 'dart:math';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import '../domain/board_geometry.dart';
import '../domain/lens_distortion.dart';

/// Diagnostic-only reprojection: manual corrections never enter recognition.
class ContactAudit {
  const ContactAudit(this.overlay, this.metrics);
  final Uint8List overlay;
  final Map<String, Object?> metrics;
}

ContactAudit? buildContactAudit(
  Uint8List bytes,
  Map metadata,
  Map hit,
  Map? correction, {
  Uint8List? emptyColor,
}) {
  if (metadata['calibration'] is! List) return null;
  final image = img.decodeImage(bytes);
  if (image == null) return null;
  final calibration = BoardCalibration(
    [
      for (final p in metadata['calibration'])
        BoardPoint((p['x'] as num).toDouble(), (p['y'] as num).toDouble()),
    ],
    lens: metadata['lens'] is Map
        ? LensDistortion.fromJson(metadata['lens'] as Map)
        : const LensDistortion(),
  );
  BoardPoint? point(Map? values) {
    final x = values?['xMillimetres'], y = values?['yMillimetres'];
    return x is num && y is num && x.isFinite && y.isFinite
        ? BoardPoint(x.toDouble(), y.toDouble())
        : null;
  }

  final estimated = point(hit), corrected = point(correction);
  final cyan = img.ColorRgb8(0, 220, 255), yellow = img.ColorRgb8(255, 210, 0);
  void line(BoardPoint a, BoardPoint b, img.Color color) {
    if (!a.x.isFinite || !a.y.isFinite || !b.x.isFinite || !b.y.isFinite) {
      return;
    }
    img.drawLine(
      image,
      x1: (a.x * (image.width - 1)).round(),
      y1: (a.y * (image.height - 1)).round(),
      x2: (b.x * (image.width - 1)).round(),
      y2: (b.y * (image.height - 1)).round(),
      color: color,
    );
  }

  for (final r in [6.35, 15.9, 99.0, 107.0, 162.0, 170.0, 230.0]) {
    for (var n = 0; n < 180; n++) {
      BoardPoint p(int k) => calibration.unproject(
        BoardPoint(sin(k * pi / 90) * r, -cos(k * pi / 90) * r),
      );
      line(p(n), p(n + 1), cyan);
    }
  }
  for (var n = 0; n < 20; n++) {
    final angle = (n + .5) * pi / 10;
    line(
      calibration.unproject(BoardPoint(sin(angle) * 15.9, -cos(angle) * 15.9)),
      calibration.unproject(BoardPoint(sin(angle) * 170, -cos(angle) * 170)),
      cyan,
    );
  }
  final axis = metadata['axis'] as Map?;
  double? axisDistance(BoardPoint? p) {
    if (p == null || axis == null) return null;
    final a = (axis['a'] as num).toDouble(),
        b = (axis['b'] as num).toDouble(),
        c = (axis['c'] as num).toDouble();
    return (a * p.x + b * p.y + c).abs() / sqrt(a * a + b * b);
  }

  if (axis != null) {
    final a = (axis['a'] as num).toDouble(),
        b = (axis['b'] as num).toDouble(),
        c = (axis['c'] as num).toDouble();
    final norm = a * a + b * b;
    final center = BoardPoint(-a * c / norm, -b * c / norm);
    final dart = DartAxis(center, center + BoardPoint(b, -a));
    final curve = calibration.imageAxis(dart);
    for (var i = 1; i < curve.length; i++) {
      line(curve[i - 1], curve[i], yellow);
    }
  }
  Map<String, Object?>? marker(
    BoardPoint? board,
    img.Color color,
    String label,
  ) {
    if (board == null) return null;
    final p = calibration.unproject(board);
    if (!p.x.isFinite || !p.y.isFinite) return {'inImage': false};
    final x = (p.x * (image.width - 1)).round(),
        y = (p.y * (image.height - 1)).round();
    final inside = x >= 0 && y >= 0 && x < image.width && y < image.height;
    if (inside) {
      img.drawCircle(image, x: x, y: y, radius: 6, color: color);
      img.drawLine(image, x1: x - 9, y1: y, x2: x + 9, y2: y, color: color);
      img.drawLine(image, x1: x, y1: y - 9, x2: x, y2: y + 9, color: color);
      img.drawString(
        image,
        label,
        font: img.arial14,
        x: max(0, min(image.width - 80, x + 8)),
        y: max(0, y - 17),
        color: color,
      );
    }
    return {
      'imageX': p.x,
      'imageY': p.y,
      'pixelX': x,
      'pixelY': y,
      'inImage': inside,
      'axisDistanceMillimetres': axisDistance(board),
      'roundTripErrorMillimetres': calibration.project(p).distanceTo(board),
    };
  }

  final predicted = marker(estimated, img.ColorRgb8(255, 30, 120), 'Detected');
  final reference = marker(corrected, img.ColorRgb8(50, 255, 80), 'Corrected');
  final empty = emptyColor == null ? null : img.decodeImage(emptyColor);
  final rings = <String, Object?>{};
  if (empty != null) {
    bool colored(BoardPoint p) {
      final q = calibration.unproject(p);
      if (!q.x.isFinite ||
          !q.y.isFinite ||
          q.x < 0 ||
          q.y < 0 ||
          q.x > 1 ||
          q.y > 1) {
        return false;
      }
      final pixel = empty.getPixel(
        (q.x * (empty.width - 1)).round(),
        (q.y * (empty.height - 1)).round(),
      );
      return (pixel.r > pixel.g * 1.25 &&
              pixel.r > pixel.b * 1.2 &&
              pixel.r > 50) ||
          (pixel.g > pixel.r * 1.15 &&
              pixel.g > pixel.b * 1.05 &&
              pixel.g > 35);
    }

    for (final ring in [('triple', 103.0), ('double', 166.0)]) {
      var hits = 0;
      for (var n = 0; n < 60; n++) {
        final a = (n + .5) * pi / 30;
        if (colored(BoardPoint(sin(a) * ring.$2, -cos(a) * ring.$2))) hits++;
      }
      rings[ring.$1] = {
        'coloredSamples': hits,
        'samples': 60,
        'fraction': hits / 60,
      };
    }
  }
  return ContactAudit(Uint8List.fromList(img.encodePng(image)), {
    'schemaVersion': 1,
    'estimated': predicted,
    'manualCorrection': reference,
    'positionDifferenceMillimetres': estimated == null || corrected == null
        ? null
        : estimated.distanceTo(corrected),
    'emptyBoardRingColorSupport': empty == null ? null : rings,
    'manualPointUsedForRecognition': false,
    'note':
        'Ring support is a color consistency check, not proof of segment orientation or true dart contact.',
  });
}
