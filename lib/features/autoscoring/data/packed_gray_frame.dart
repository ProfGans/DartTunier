import 'dart:io';
import 'package:flutter/foundation.dart';
import '../domain/frame_detector.dart';

/// Evidence keeps compressed detail references; live detection uses raw pixels.
/// Weak keys reuse shared references without retaining their full pixel buffers.
class PackedGrayFrame {
  PackedGrayFrame._(this.width, this.height, this._pixels);
  final int width, height;
  Uint8List? _pixels, _bytes;
  Uint8List get bytes {
    _bytes ??= _compress(_pixels!);
    _pixels = null;
    return _bytes!;
  }

  static Future<void> _queue = Future.value();
  static Future<void> flush() => _queue;
  static final _cache = Expando<PackedGrayFrame>();
  factory PackedGrayFrame.fromFrame(GrayFrame frame) {
    final cached = _cache[frame];
    if (cached != null) return cached;
    final packed = PackedGrayFrame._(
      frame.width,
      frame.height,
      Uint8List.fromList(frame.pixels),
    );
    _cache[frame] = packed;
    // One background job at a time avoids an isolate storm after each throw.
    // Capture owns a copy immediately; native buffers may safely be reused.
    _queue = _queue
        .then((_) async {
          if (packed._bytes != null) return;
          final compressed = await compute(_compress, packed._pixels!);
          packed._bytes ??= compressed;
          packed._pixels = null;
        })
        .catchError((Object _) {
          // Export can still compress synchronously if background packing failed.
        });
    return packed;
  }
  GrayFrame unpack() =>
      GrayFrame(width, height, Uint8List.fromList(ZLibCodec().decode(bytes)));
}

Uint8List _compress(Uint8List pixels) =>
    Uint8List.fromList(ZLibCodec(level: 1).encode(pixels));
