import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:zxing_lib/qrcode.dart';
import 'package:zxing_lib/zxing.dart';
import 'package:zxing_lib/common.dart';

/// Runs locally in an isolate. Camera images are never uploaded.
String? decodeQrImage(Uint8List bytes) {
  if (bytes.length < 8) return null;
  img.Image? image;
  try {
    image = img.decodeImage(bytes);
  } on FormatException {
    return null;
  } on RangeError {
    return null;
  }
  if (image == null) return null;
  image = img.bakeOrientation(image);
  if (image.width > 1280 || image.height > 1280) {
    image = img.copyResize(
      image,
      width: image.width >= image.height ? 1280 : null,
      height: image.height > image.width ? 1280 : null,
    );
  }
  final pixels = Uint8List(image.width * image.height);
  for (final p in image) {
    pixels[p.y * image.width + p.x] = (p.r * .299 + p.g * .587 + p.b * .114)
        .round();
  }
  final source = RGBLuminanceSource.orig(image.width, image.height, pixels);
  for (final luminance in [source, source.invert()]) {
    try {
      return QRCodeReader()
          .decode(
            BinaryBitmap(HybridBinarizer(luminance)),
            DecodeHint(tryHarder: true),
          )
          .text;
    } on ReaderException {
      // No QR code yet; the next camera frame may contain one.
    }
  }
  return null;
}
