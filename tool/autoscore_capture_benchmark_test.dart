import 'dart:io';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_tournament_manager/features/autoscoring/domain/frame_detector.dart';
import 'package:dart_tournament_manager/features/autoscoring/data/packed_gray_frame.dart';

void main() {
  test(
    'Compare synchronous diagnostic packing with background capture',
    () async {
      final frames = <GrayFrame>[];
      for (var camera = 1; camera <= 3; camera++) {
        for (var n = 1; n <= 8; n++) {
          final decoded = decodeCameraFrame(
            File(
              'test/fixtures/autoscoring/new_video/case_94/kamera_${camera}_sequenz_${n}_detail.png',
            ).readAsBytesSync(),
          );
          frames.add(decoded.detail ?? decoded);
        }
      }
      final old = Stopwatch()..start();
      final reference = [
        for (final f in frames) ZLibCodec(level: 1).encode(f.pixels),
      ];
      old.stop();
      final capture = Stopwatch()..start();
      final packed = [for (final f in frames) PackedGrayFrame.fromFrame(f)];
      capture.stop();
      await PackedGrayFrame.flush();
      for (var i = 0; i < frames.length; i++) {
        expect(packed[i].bytes, reference[i]);
        expect(packed[i].unpack().pixels, frames[i].pixels);
      }
      File(
        'build/autoscore_analysis/case94_capture_benchmark.json',
      ).writeAsStringSync(
        jsonEncode({
          'frames': frames.length,
          'pixels': frames.fold<int>(0, (s, f) => s + f.pixels.length),
          'synchronousCompressionMilliseconds': old.elapsedMicroseconds / 1000,
          'captureCopyMilliseconds': capture.elapsedMicroseconds / 1000,
          'lossless': true,
          'liveUsbLatencyMeasured': false,
        }),
      );
    },
  );
}
