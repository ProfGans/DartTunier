import 'dart:math';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'automatic_board_calibration.dart';
import 'board_geometry.dart';

class ReferenceCalibrationInput {
  const ReferenceCalibrationInput(
    this.target,
    this.reference,
    this.calibration,
  );
  final Uint8List target, reference;
  final BoardCalibration calibration;
}

/// Align the complete printed number ring between views. The playing sectors
/// are excluded because their repeated pattern cannot resolve board rotation.
AutomaticCalibrationResult calibrateFromReference(
  ReferenceCalibrationInput input,
) {
  final target = detectBoardOutline(input.target);
  final reference = detectBoardOutline(input.reference);
  const angles = 512, radial = 16;
  List<double> profile(Uint8List bytes) {
    final image = img.decodePng(bytes)!;
    final values = List<double>.filled(angles * radial, 0);
    for (var r = 0; r < radial; r++) {
      var mean = 0.0;
      for (var a = 0; a < angles; a++) {
        final theta = a * 2 * pi / angles,
            radius = 1.065 + r / (radial - 1) * .25;
        final x =
            (sin(theta) * radius / AutomaticCalibrationImage.extent + 1) /
            2 *
            (image.width - 1);
        final y =
            (-cos(theta) * radius / AutomaticCalibrationImage.extent + 1) /
            2 *
            (image.height - 1);
        final value = image
            .getPixelInterpolate(x, y, interpolation: img.Interpolation.linear)
            .r
            .toDouble();
        values[a * radial + r] = value;
        mean += value;
      }
      mean /= angles;
      for (var a = 0; a < angles; a++) {
        values[a * radial + r] -= mean;
      }
    }
    return values;
  }

  final t = profile(target.ocrImage), s = profile(reference.ocrImage);
  final norm = sqrt(
    t.fold<double>(0, (sum, x) => sum + x * x) *
        s.fold<double>(0, (sum, x) => sum + x * x),
  );
  if (norm < 1e-6) {
    throw CalibrationFailure(
      'Zahlenring enthält zu wenig Bilddetails für den Kamera-Abgleich.',
      diagnostics: target.diagnostics,
    );
  }
  final scores = List<double>.filled(angles, 0);
  var best = 0;
  for (var shift = 0; shift < angles; shift++) {
    var dot = 0.0;
    for (var a = 0; a < angles; a++) {
      for (var r = 0; r < radial; r++) {
        dot += t[a * radial + r] * s[((a + shift) % angles) * radial + r];
      }
    }
    scores[shift] = dot / norm;
    if (scores[shift] > scores[best]) best = shift;
  }
  var alternative = -1.0;
  for (var shift = 0; shift < angles; shift++) {
    final distance = min((shift - best).abs(), angles - (shift - best).abs());
    if (distance > 18) alternative = max(alternative, scores[shift]);
  }
  if (scores[best] < .30 || scores[best] - alternative < .06) {
    throw CalibrationFailure(
      'Zahlenring zwischen Kameras nicht eindeutig zuzuordnen (${scores[best].toStringAsFixed(2)}, ${alternative.toStringAsFixed(2)}).',
      diagnostics: target.diagnostics,
    );
  }
  final top = reference.outline.rectify(input.calibration.points.first);
  final rotation = atan2(top.x, -top.y) - best * 2 * pi / angles;
  final points = [
    for (var i = 0; i < 4; i++)
      target.outline.unrectify(
        Point(sin(rotation + i * pi / 2), -cos(rotation + i * pi / 2)),
      ),
  ];
  return AutomaticCalibrationResult(
    BoardCalibration(points),
    0,
    diagnostics: target.diagnostics,
  );
}
