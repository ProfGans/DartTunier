import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  test('Measure live color encoding separately from recognition', () {
    final images = [
      for (var camera = 1; camera <= 3; camera++)
        img.copyResize(
          img.decodeImage(
            File(
              'test/fixtures/autoscoring/new_video/case_94/kamera_${camera}_leer_farbe.jpg',
            ).readAsBytesSync(),
          )!,
          width: 640,
        ),
    ];
    List<Map<String, Object>> measure() => [
      for (final codec in ['jpeg85', 'png1'])
        (() {
          final watch = Stopwatch()..start();
          final bytes = [
            for (final image in images)
              codec == 'jpeg85'
                  ? img.encodeJpg(image, quality: 85)
                  : img.encodePng(image, level: 1, filter: img.PngFilter.none),
          ];
          watch.stop();
          for (var i = 0; i < bytes.length; i++) {
            expect(img.decodeImage(bytes[i])!.width, images[i].width);
          }
          return <String, Object>{
            'codec': codec,
            'threeCameraMilliseconds': watch.elapsedMicroseconds / 1000,
            'totalBytes': bytes.fold<int>(0, (s, b) => s + b.length),
          };
        })(),
    ];
    measure(); // Warm both encoders before comparing.
    File(
      'build/autoscore_analysis/color_overhead_benchmark.json',
    ).writeAsStringSync(jsonEncode([for (var n = 0; n < 3; n++) measure()]));
  });
}
