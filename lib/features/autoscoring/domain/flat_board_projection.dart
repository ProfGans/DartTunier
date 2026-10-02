import 'dart:math';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'board_geometry.dart';
import '../../scorer/domain/x01/x01_rules.dart';

class FlatBoardCamera {
  const FlatBoardCamera(this.image, this.calibration);
  final Uint8List image;
  final BoardCalibration calibration;
}

/// Projects the board plane from each calibrated view into a shared mm space.
/// Darts extend out of this plane, so their shafts can appear in several places.
Uint8List projectFlatBoard(List<FlatBoardCamera> cameras) {
  const size = 480, extent = 190.0;
  final views = [
    for (final camera in cameras)
      (img.decodeImage(camera.image), camera.calibration),
  ];
  final output = img.Image(width: size, height: size);
  img.fill(output, color: img.ColorRgb8(35, 35, 35));
  for (var y = 0; y < size; y++) {
    for (var x = 0; x < size; x++) {
      final q = Point(
        (x / (size - 1) * 2 - 1) * extent,
        (y / (size - 1) * 2 - 1) * extent,
      );
      if (q.magnitude > 180) continue;
      var r = 0.0, g = 0.0, b = 0.0, count = 0;
      for (final view in views) {
        final image = view.$1;
        if (image == null) continue;
        final p = view.$2.unproject(q);
        if (!p.x.isFinite ||
            !p.y.isFinite ||
            p.x < 0 ||
            p.x > 1 ||
            p.y < 0 ||
            p.y > 1) {
          continue;
        }
        final pixel = image.getPixelInterpolate(
          p.x * (image.width - 1),
          p.y * (image.height - 1),
          interpolation: img.Interpolation.linear,
        );
        r += pixel.r;
        g += pixel.g;
        b += pixel.b;
        count++;
      }
      if (count > 0) output.setPixelRgb(x, y, r / count, g / count, b / count);
    }
  }
  for (var sector = 0; sector < 20; sector++) {
    final angle = sector * pi / 10;
    final label = '${X01Rules.wheel[sector]}';
    img.drawString(
      output,
      label,
      font: img.arial14,
      x: ((.5 + sin(angle) * 183 / 380) * (size - 1) - label.length * 4)
          .round(),
      y: ((.5 - cos(angle) * 183 / 380) * (size - 1) - 7).round(),
      color: img.ColorRgb8(255, 255, 255),
    );
  }
  return Uint8List.fromList(img.encodePng(output));
}
