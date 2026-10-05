import 'dart:math';
import 'dart:io';
import '../../../shared/platform/linux_ocr.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import '../domain/automatic_board_calibration.dart';
import '../domain/ocr_board_numbers.dart';
import '../domain/board_number_sheet.dart';
import '../domain/board_geometry.dart';
import '../domain/board_calibration_refinement.dart';
import '../domain/dense_board_calibration.dart';
import '../domain/reference_board_calibration.dart';
import 'calibration_reference_storage.dart';

AutomaticCalibrationResult _refineCalibration(
  (Uint8List, AutomaticCalibrationResult) input,
) {
  final refined = refineDenseBoard(
    input.$1,
    refineBoardCalibration(input.$1, input.$2.calibration),
  );
  return AutomaticCalibrationResult(
    refined.calibration,
    input.$2.numberCount,
    diagnostics: input.$2.diagnostics,
    quality: refined.metrics,
  );
}

abstract class AutomaticCalibrationService {
  Future<AutomaticCalibrationResult> calibrate(Uint8List image);
}

abstract class ReferenceAutomaticCalibrationService
    implements AutomaticCalibrationService {
  Future<AutomaticCalibrationResult> calibrateUsingReference(
    Uint8List target,
    Uint8List reference,
    BoardCalibration calibration,
  );
}

/// Windows OCR runs locally. The channel takes raw BGRA pixels and returns
/// text bounding boxes; geometry and matching remain testable Dart libraries.
class WindowsAutomaticCalibrationService
    implements
        AutomaticCalibrationService,
        ReferenceAutomaticCalibrationService {
  const WindowsAutomaticCalibrationService({
    this.channel = const MethodChannel('dart_tournament/autoscoring_ocr'),
    this.onNumbers,
    this.onWords,
    this.useReferenceCache = true,
  });
  final MethodChannel channel;
  final void Function(List<BoardNumber>)? onNumbers;
  final void Function(int, List<dynamic>)? onWords;
  final bool useReferenceCache;
  Future<List<dynamic>?> _recognize(String method, Map<String, Object> input) =>
      Platform.isLinux
      ? LinuxOcr.recognize(input)
      : channel.invokeMethod<List<dynamic>>(method, input);
  Future<AutomaticCalibrationResult> _remember(
    AutomaticCalibrationResult result,
    Uint8List image,
  ) async {
    result = await compute(_refineCalibration, (image, result));
    if (useReferenceCache) {
      try {
        await const CalibrationReferenceStorage().remember(
          image,
          result.calibration,
        );
      } catch (_) {
        /* A valid calibration remains usable without a cache. */
      }
    }
    return result;
  }

  @override
  Future<AutomaticCalibrationResult> calibrateUsingReference(
    Uint8List target,
    Uint8List reference,
    BoardCalibration calibration,
  ) async {
    final result = await compute(
      calibrateFromReference,
      ReferenceCalibrationInput(target, reference, calibration),
    );
    return compute(_refineCalibration, (target, result));
  }

  @override
  Future<AutomaticCalibrationResult> calibrate(Uint8List image) async {
    if (useReferenceCache) {
      try {
        for (final reference
            in await const CalibrationReferenceStorage().load()) {
          try {
            return await calibrateUsingReference(
              image,
              reference.image,
              reference.calibration,
            );
          } on CalibrationFailure {
            continue;
          }
        }
      } catch (_) {
        /* Read the numbers afresh when no usable reference exists. */
      }
    }
    final prepared = await compute(detectBoardOutline, image);
    final numbers = <BoardNumber>[];
    final rectified = img.decodePng(prepared.ocrImage)!;
    for (final rotation in [0, 90, 180, 270]) {
      final rotated = rotation == 0
          ? rectified
          : img.copyRotate(rectified, angle: rotation);
      final pixels = Uint8List(rotated.width * rotated.height * 4);
      for (final p in rotated) {
        final i = (p.y * rotated.width + p.x) * 4;
        pixels[i] = p.b.toInt();
        pixels[i + 1] = p.g.toInt();
        pixels[i + 2] = p.r.toInt();
        pixels[i + 3] = 255;
      }
      late List<dynamic> words;
      try {
        words =
            await _recognize('recognize', {
              'width': rotated.width,
              'height': rotated.height,
              'pixels': pixels,
            }) ??
            [];
      } on MissingPluginException {
        throw CalibrationFailure(
          'Automatische Zahlenerkennung benötigt die neu gebaute Windows-Version.',
          diagnostics: prepared.diagnostics,
        );
      } on PlatformException catch (e) {
        throw CalibrationFailure(
          'Lokale Zahlenerkennung nicht verfügbar: ${e.message ?? e.code}',
          diagnostics: prepared.diagnostics,
        );
      }
      onWords?.call(rotation, words);
      numbers.addAll(
        readOcrBoardNumbers(
          words,
          rotation: rotation,
          width: rotated.width,
          height: rotated.height,
        ),
      );
    }
    onNumbers?.call(numbers);
    try {
      return _remember(
        resolveBoardOrientation(
          prepared.outline,
          numbers,
          diagnostics: prepared.diagnostics,
        ),
        image,
      );
    } on CalibrationFailure {
      final source = img.decodeImage(image)!;
      final raw = img.Image(width: source.width, height: source.height);
      img.fill(raw, color: img.ColorRgb8(255, 255, 255));
      for (final p in source) {
        final radius = prepared.outline
            .rectify(Point(p.x / (source.width - 1), p.y / (source.height - 1)))
            .magnitude;
        if (radius < 1.025 || radius > 1.38) continue;
        final gray = 255 - (p.r * .299 + p.g * .587 + p.b * .114).round();
        raw.setPixelRgb(p.x, p.y, gray, gray, gray);
      }
      for (final rotation in [0, 90, 180, 270]) {
        final rotated = rotation == 0
            ? raw
            : img.copyRotate(raw, angle: rotation);
        final pixels = Uint8List(rotated.width * rotated.height * 4);
        for (final p in rotated) {
          final offset = (p.y * rotated.width + p.x) * 4;
          pixels[offset] = p.b.toInt();
          pixels[offset + 1] = p.g.toInt();
          pixels[offset + 2] = p.r.toInt();
          pixels[offset + 3] = 255;
        }
        final words =
            await _recognize('recognize', {
              'width': rotated.width,
              'height': rotated.height,
              'pixels': pixels,
            }) ??
            [];
        onWords?.call(1000 + rotation, words);
        for (final n in readOcrBoardNumbers(
          words,
          rotation: rotation,
          width: rotated.width,
          height: rotated.height,
        )) {
          final p = Point(
            (n.position.x / AutomaticCalibrationImage.extent + 1) / 2,
            (n.position.y / AutomaticCalibrationImage.extent + 1) / 2,
          );
          numbers.add(BoardNumber(n.value, prepared.outline.rectify(p)));
        }
      }
      onNumbers?.call(numbers);
      try {
        return _remember(
          resolveBoardOrientation(
            prepared.outline,
            numbers,
            diagnostics: prepared.diagnostics,
          ),
          image,
        );
      } on CalibrationFailure {
        // Continue with upright numeral tiles when the original view fails.
      }
      // Board numerals rotate around the ring. Present overlapping local
      // tangential views upright instead of asking OCR to read a whole circle.
      const tile = numberSheetTile, columns = numberSheetColumns;
      final sheet = createBoardNumberSheet(rectified);
      final pixels = Uint8List(sheet.width * sheet.height * 4);
      for (final p in sheet) {
        final offset = (p.y * sheet.width + p.x) * 4;
        pixels[offset] = p.b.toInt();
        pixels[offset + 1] = p.g.toInt();
        pixels[offset + 2] = p.r.toInt();
        pixels[offset + 3] = 255;
      }
      final words = List<dynamic>.of(
        await _recognize('recognize', {
              'width': sheet.width,
              'height': sheet.height,
              'pixels': pixels,
            }) ??
            [],
      );
      // Some boards print digits facing inward. A half-turn reads these
      // without assuming the board's physical rotation.
      final reversedPixels = Uint8List(pixels.length);
      for (var i = 0; i < pixels.length; i += 4) {
        final j = pixels.length - i - 4;
        reversedPixels.setRange(i, i + 4, pixels, j);
      }
      final reversedWords =
          await _recognize('recognize', {
            'width': sheet.width,
            'height': sheet.height,
            'pixels': reversedPixels,
          }) ??
          [];
      for (final word in reversedWords) {
        if (word is! Map) continue;
        words.add({
          ...word,
          'x': sheet.width - (word['x'] as num) - (word['width'] as num),
          'y': sheet.height - (word['y'] as num) - (word['height'] as num),
        });
      }
      onWords?.call(360, words);
      for (final word in words) {
        if (word is! Map) continue;
        final value = int.tryParse('${word['text']}');
        if (value == null || value < 1 || value > 20) continue;
        final x =
            (word['x'] as num).toDouble() +
            (word['width'] as num).toDouble() / 2;
        final y =
            (word['y'] as num).toDouble() +
            (word['height'] as num).toDouble() / 2;
        final col = x ~/ tile, row = y ~/ tile;
        if (col < 0 || col >= columns || row < 0 || row >= 5) continue;
        numbers.add(
          BoardNumber(
            value,
            numberSheetPoint(row * columns + col, x % tile, y % tile),
          ),
        );
      }
      onNumbers?.call(numbers);
      try {
        return _remember(
          resolveBoardOrientation(
            prepared.outline,
            numbers,
            diagnostics: prepared.diagnostics,
          ),
          image,
        );
      } on CalibrationFailure {
        // Windows OCR may treat a grid of isolated digits as artwork. Read
        // individual tiles only when the faster whole-sheet pass fails.
        for (var index = 0; index < 40; index++) {
          for (final reverse in [false, true]) {
            final tilePixels = Uint8List(tile * tile * 4);
            for (var y = 0; y < tile; y++) {
              for (var x = 0; x < tile; x++) {
                final sourceX =
                    index % columns * tile + (reverse ? tile - 1 - x : x);
                final sourceY =
                    index ~/ columns * tile + (reverse ? tile - 1 - y : y);
                final offset = (sourceY * sheet.width + sourceX) * 4;
                tilePixels.setRange(
                  (y * tile + x) * 4,
                  (y * tile + x) * 4 + 4,
                  pixels,
                  offset,
                );
              }
            }
            final tileWords =
                await _recognize('recognize', {
                  'width': tile,
                  'height': tile,
                  'pixels': tilePixels,
                }) ??
                [];
            onWords?.call(400 + index * 2 + (reverse ? 1 : 0), tileWords);
            for (final word in tileWords) {
              if (word is! Map) continue;
              final value = int.tryParse('${word['text']}');
              if (value == null || value < 1 || value > 20) continue;
              var x =
                  (word['x'] as num).toDouble() +
                  (word['width'] as num).toDouble() / 2;
              var y =
                  (word['y'] as num).toDouble() +
                  (word['height'] as num).toDouble() / 2;
              if (reverse) {
                x = tile - 1 - x;
                y = tile - 1 - y;
              }
              numbers.add(BoardNumber(value, numberSheetPoint(index, x, y)));
            }
          }
        }
        onNumbers?.call(numbers);
        return _remember(
          resolveBoardOrientation(
            prepared.outline,
            numbers,
            diagnostics: prepared.diagnostics,
          ),
          image,
        );
      }
    }
  }
}
