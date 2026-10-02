import 'dart:math';
import 'automatic_board_calibration.dart';

/// Windows OCR boxes refer to the deskewed bitmap. Undo its TextAngle before
/// undoing our explicit image rotation. Otherwise different OCR passes disagree.
List<BoardNumber> readOcrBoardNumbers(
  List<dynamic> words, {
  required int rotation,
  required int width,
  required int height,
}) {
  final numbers = <BoardNumber>[];
  for (final item in words) {
    final word = Map<Object?, Object?>.from(item as Map);
    final text = (word['text'] as String).trim().replaceAll('O', '0');
    if (!RegExp(r'^\d{1,2}$').hasMatch(text)) continue;
    final value = int.tryParse(text);
    if (value == null || value < 1 || value > 20) continue;
    final dx = (word['x'] as num) + (word['width'] as num) / 2 - width / 2;
    final dy = (word['y'] as num) + (word['height'] as num) / 2 - height / 2;
    final angle = ((word['textAngle'] as num?)?.toDouble() ?? 0) * pi / 180;
    final x = (width / 2 + cos(angle) * dx - sin(angle) * dy) / (width - 1);
    final y = (height / 2 + sin(angle) * dx + cos(angle) * dy) / (height - 1);
    final point = switch (rotation) {
      90 => Point(y, 1 - x),
      180 => Point(1 - x, 1 - y),
      270 => Point(1 - y, x),
      _ => Point(x, y),
    };
    numbers.add(
      BoardNumber(
        value,
        Point(
          (point.x * 2 - 1) * AutomaticCalibrationImage.extent,
          (point.y * 2 - 1) * AutomaticCalibrationImage.extent,
        ),
      ),
    );
  }
  return numbers;
}
