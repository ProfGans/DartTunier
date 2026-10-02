import 'dart:math';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:dart_tournament_manager/features/autoscoring/domain/board_calibration_refinement.dart';
import 'package:dart_tournament_manager/features/autoscoring/domain/board_geometry.dart';
import 'automatic_calibration_test.dart' show boardImage;
import 'package:dart_tournament_manager/features/autoscoring/domain/automatic_board_calibration.dart';

void main() {
  final outline = BoardOutline(
    const Point(.5, .5),
    .4,
    .35,
    0,
    const Point(.5, .5),
  );
  BoardCalibration calibration(double angle, double scale) => BoardCalibration([
    for (final a in [0.0, pi / 2, pi, 3 * pi / 2])
      outline.unrectify(Point(sin(a + angle) * scale, -cos(a + angle) * scale)),
  ]);
  test('Whole-board edges refine small rotation and scale without labels', () {
    final bytes = img.encodePng(boardImage(outline));
    final initial = calibration(2 * pi / 180, 1.02);
    final refined = refineBoardCalibration(bytes, initial);
    for (final q in [const Point(25.0, -130.0), const Point(-60.0, 80.0)]) {
      final imagePoint = outline.unrectify(q * (1 / 170));
      expect((refined.project(imagePoint) - q).magnitude, lessThan(2));
      expect(
        (refined.project(imagePoint) - q).magnitude,
        lessThan((initial.project(imagePoint) - q).magnitude),
      );
    }
  });
  test('Uniform or invalid images preserve initial geometry', () {
    final initial = calibration(0, 1);
    final blank = img.Image(width: 640, height: 480);
    img.fill(blank, color: img.ColorRgb8(100, 100, 100));
    expect(
      refineBoardCalibration(img.encodePng(blank), initial),
      same(initial),
    );
    expect(refineBoardCalibration(Uint8List(0), initial), same(initial));
  });
  test('Already aligned board remains accurate', () {
    final initial = calibration(0, 1);
    final refined = refineBoardCalibration(
      img.encodePng(boardImage(outline)),
      initial,
    );
    const q = Point(25.0, -130.0);
    expect((refined.project(initial.unproject(q)) - q).magnitude, lessThan(2));
  });
}
