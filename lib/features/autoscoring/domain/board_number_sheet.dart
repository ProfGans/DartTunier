import 'dart:math';
import 'package:image/image.dart' as img;
import 'automatic_board_calibration.dart';
import 'board_geometry.dart';

const numberSheetTile = 128, numberSheetColumns = 8;
const tile = numberSheetTile, columns = numberSheetColumns;
BoardPoint numberSheetPoint(int index, double x, double y) {
  final angle = index * pi / 20;
  final r = 1.31 - y / (tile - 1) * .25;
  final t = (x / (tile - 1) * 2 - 1) * .19;
  return Point(
    sin(angle) * r + cos(angle) * t,
    -cos(angle) * r + sin(angle) * t,
  );
}

img.Image createBoardNumberSheet(img.Image rectified) {
  final sheet = img.Image(width: tile * columns, height: tile * 5);
  img.fill(sheet, color: img.ColorRgb8(255, 255, 255));
  for (var index = 0; index < 40; index++) {
    for (var y = 8; y < tile - 8; y++) {
      for (var x = 8; x < tile - 8; x++) {
        final q = numberSheetPoint(index, x.toDouble(), y.toDouble());
        final sx =
            ((q.x / AutomaticCalibrationImage.extent + 1) /
                    2 *
                    (rectified.width - 1))
                .round();
        final sy =
            ((q.y / AutomaticCalibrationImage.extent + 1) /
                    2 *
                    (rectified.height - 1))
                .round();
        if (sx < 0 ||
            sy < 0 ||
            sx >= rectified.width ||
            sy >= rectified.height) {
          continue;
        }
        final color = rectified.getPixel(sx, sy);
        final gray = ((color.r - 80) * 255 / 140).round().clamp(0, 255);
        sheet.setPixelRgb(
          index % columns * tile + x,
          index ~/ columns * tile + y,
          gray,
          gray,
          gray,
        );
      }
    }
    // Remove border arcs and cut-off lettering. They otherwise join a numeral
    // into a large graphic that Windows OCR skips. Overlapping tiles retain
    // numerals that touch an edge in another view.
    final visited = List<bool>.filled(tile * tile, false);
    for (var start = 0; start < visited.length; start++) {
      final sx = index % columns * tile + start % tile;
      final sy = index ~/ columns * tile + start ~/ tile;
      if (visited[start] || sheet.getPixel(sx, sy).r >= 100) continue;
      final stack = [start], component = <int>[];
      visited[start] = true;
      var edge = false;
      while (stack.isNotEmpty) {
        final p = stack.removeLast(), x = p % tile, y = p ~/ tile;
        component.add(p);
        if (x <= 8 || y <= 8 || x >= tile - 9 || y >= tile - 9) edge = true;
        for (final next in [
          if (x > 0) p - 1,
          if (x + 1 < tile) p + 1,
          if (y > 0) p - tile,
          if (y + 1 < tile) p + tile,
        ]) {
          if (visited[next]) continue;
          final px = index % columns * tile + next % tile;
          final py = index ~/ columns * tile + next ~/ tile;
          if (sheet.getPixel(px, py).r < 100) {
            visited[next] = true;
            stack.add(next);
          }
        }
      }
      if (edge) {
        for (final p in component) {
          sheet.setPixelRgb(
            index % columns * tile + p % tile,
            index ~/ columns * tile + p ~/ tile,
            255,
            255,
            255,
          );
        }
      }
    }
  }
  return sheet;
}
