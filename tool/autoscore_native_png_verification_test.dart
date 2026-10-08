import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:dart_tournament_manager/features/autoscoring/application/decode_video_frames.dart';
import 'package:dart_tournament_manager/features/autoscoring/domain/video_frame_synchronizer.dart';

void main() {
  test(
    'Native PNG preserves real board colors and eliminates Dart JPEG encoding',
    () async {
      final rows = <Map<String, Object?>>[];
      final nativeProbe = File(
        'build/autoscore_native_probe/Release/autoscore_native_probe.exe',
      ).absolute.path;
      for (var camera = 1; camera <= 3; camera++) {
        final image = img.decodeImage(
          File(
            'test/fixtures/autoscoring/new_video/case_94/kamera_${camera}_leer_farbe.jpg',
          ).readAsBytesSync(),
        )!;
        final rgb = image.getBytes(order: img.ChannelOrder.rgb);
        final path = File(
          'build/autoscore_native_probe/real_board_$camera.rgb',
        ).absolute.path;
        File(path).writeAsBytesSync(rgb);
        final encoded = await Process.run(nativeProbe, [
          path,
          '${image.width}',
          '${image.height}',
        ]);
        expect(encoded.exitCode, 0, reason: '${encoded.stderr}');
        final bytes = File('$path.png').readAsBytesSync();
        final decoded = img.decodePng(bytes)!;
        expect(decoded.getBytes(order: img.ChannelOrder.rgb), rgb);
        final original = CameraVideoFrame(
          camera,
          camera * 1000,
          1,
          image.width,
          image.height,
          rgb,
        );
        final expected = decodeVideoFrames([original]).single;
        final compact = CameraVideoFrame.fromMap({
          'cameraId': camera,
          'timestampUs': camera * 1000,
          'sequence': 1,
          'width': image.width,
          'height': image.height,
          'colorWidth': image.width,
          'colorHeight': image.height,
          'rgb': Uint8List(0),
          'gray': expected.detail?.pixels ?? expected.pixels,
          'colorImage': bytes,
        });
        // This fixture is 640 pixels wide, so detail contains the exact native gray.
        expect(compact.width, greaterThan(480));
        final oldTimes = <double>[], newTimes = <double>[];
        for (var n = 0; n < 5; n++) {
          final watch = Stopwatch()..start();
          final before = await compute(decodeVideoFrames, [original]);
          oldTimes.add(watch.elapsedMicroseconds / 1000);
          watch.reset();
          final after = await compute(decodeVideoFrames, [compact]);
          newTimes.add(watch.elapsedMicroseconds / 1000);
          expect(after.single.pixels, before.single.pixels);
          expect(after.single.detail!.pixels, before.single.detail!.pixels);
          expect(after.single.colorImage, bytes);
        }
        rows.add({
          'camera': camera,
          'nativePng': jsonDecode(encoded.stdout as String),
          'dartRgbAndJpegMilliseconds': oldTimes,
          'dartNativeGrayAndPngMilliseconds': newTimes,
          'exactColorAndGrayPixels': true,
        });
      }
      File(
        'build/autoscore_analysis/native_png_benchmark.json',
      ).writeAsStringSync(jsonEncode(rows));
    },
  );
}
