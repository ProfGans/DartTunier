import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

Future<String> encodeProfileImage(Uint8List bytes) => compute(_encode, bytes);

String _encode(Uint8List bytes) {
  try {
    return _encodeImage(bytes);
  } on FormatException {
    rethrow;
  } catch (_) {
    throw const FormatException('Bild konnte nicht gelesen werden.');
  }
}

String _encodeImage(Uint8List bytes) {
  if (bytes.length > 5 * 1024 * 1024) {
    throw const FormatException('Bitte ein Bild unter 5 MB auswählen.');
  }
  final decoder = img.findDecoderForData(bytes);
  final info = decoder?.startDecode(bytes);
  if (info == null ||
      info.width <= 0 ||
      info.height <= 0 ||
      info.width * info.height > 20000000) {
    throw const FormatException(
      'Das Bild ist ungültig oder zu groß (maximal 20 Megapixel).',
    );
  }
  final decoded = decoder!.decodeFrame(0);
  if (decoded == null) {
    throw const FormatException('Bild konnte nicht gelesen werden.');
  }
  final thumbnail = img.copyResizeCropSquare(
    img.bakeOrientation(decoded),
    size: 256,
  );
  final encoded = base64Encode(img.encodeJpg(thumbnail, quality: 80));
  if (encoded.length > 131072) {
    throw const FormatException('Das Bild ist zu groß.');
  }
  return encoded;
}
