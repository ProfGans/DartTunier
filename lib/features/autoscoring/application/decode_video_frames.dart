import 'dart:math';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import '../domain/frame_detector.dart';
import '../domain/video_frame_synchronizer.dart';

List<GrayFrame> decodeVideoFrames(List<CameraVideoFrame> frames) => [
  for (final frame in frames) _decode(frame),
];

GrayFrame _decode(CameraVideoFrame frame) {
  final gray = frame.gray ?? Uint8List(frame.width * frame.height);
  if (frame.gray == null) {
    for (var i = 0; i < gray.length; i++) {
      final p = i * 3;
      gray[i] =
          (frame.rgb[p] * 77 +
              frame.rgb[p + 1] * 150 +
              frame.rgb[p + 2] * 29) >>
          8;
    }
  }
  final width = min(480, frame.width),
      height = max(1, frame.height * width ~/ frame.width);
  final pixels = Uint8List(width * height);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      pixels[y * width + x] =
          gray[(y * frame.height ~/ height) * frame.width +
              x * frame.width ~/ width];
    }
  }
  Uint8List? color = frame.colorImage;
  if (color == null) {
    final rgb = img.Image.fromBytes(
      width: frame.rgbWidth,
      height: frame.rgbHeight,
      bytes: frame.rgb.buffer,
      bytesOffset: frame.rgb.offsetInBytes,
      numChannels: 3,
    );
    color = img.encodeJpg(
      rgb.width <= 640 ? rgb : img.copyResize(rgb, width: 640),
      quality: 85,
    );
  }
  return GrayFrame(
    width,
    height,
    pixels,
    sourceAspectRatio: frame.width / frame.height,
    colorImage: color,
    timestampUs: frame.timestampUs,
    sequence: frame.sequence,
    detail: frame.width > 480
        ? GrayFrame(frame.width, frame.height, gray)
        : null,
  );
}
