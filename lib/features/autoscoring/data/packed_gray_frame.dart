import 'dart:io';
import 'dart:typed_data';
import '../domain/frame_detector.dart';

/// Evidence keeps compressed detail references; live detection uses raw pixels.
/// Weak keys reuse shared references without retaining their full pixel buffers.
class PackedGrayFrame {
  PackedGrayFrame._(this.width, this.height, this.bytes);
  final int width, height;
  final Uint8List bytes;
  static final _cache = Expando<PackedGrayFrame>();
  factory PackedGrayFrame.fromFrame(GrayFrame frame) =>
      _cache[frame] ??= PackedGrayFrame._(
        frame.width,
        frame.height,
        Uint8List.fromList(ZLibCodec(level: 1).encode(frame.pixels)),
      );
  GrayFrame unpack() =>
      GrayFrame(width, height, Uint8List.fromList(ZLibCodec().decode(bytes)));
}
