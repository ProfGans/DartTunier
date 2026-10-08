import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:dart_tournament_manager/features/autoscoring/application/decode_video_frames.dart';
import 'package:dart_tournament_manager/features/autoscoring/domain/video_frame_synchronizer.dart';

void main() {
  for (final size in [(1280, 720), (800, 601)]) {
    test(
      'Compact native payload preserves all recognition pixels at $size',
      () {
        final (width, height) = size;
        final image = img.Image(width: width, height: height);
        final gray = Uint8List(width * height);
        for (var y = 0; y < height; y++) {
          for (var x = 0; x < width; x++) {
            final r = (x * 13 + y * 11) % 256,
                g = (x + y * 7) % 256,
                b = (x * 3 + y) % 256;
            image.setPixelRgb(x, y, r, g, b);
            gray[y * width + x] = (r * 77 + g * 150 + b * 29) >> 8;
          }
        }
        final color = img.copyResize(image, width: 640);
        final original = CameraVideoFrame(
          1,
          1000,
          7,
          width,
          height,
          image.getBytes(order: img.ChannelOrder.rgb),
        );
        final compact = CameraVideoFrame.fromMap({
          'cameraId': 1,
          'timestampUs': 1000,
          'sequence': 7,
          'width': width,
          'height': height,
          'rgb': color.getBytes(order: img.ChannelOrder.rgb),
          'colorWidth': color.width,
          'colorHeight': color.height,
          'gray': gray,
          'ageUs': 23000,
        });
        final before = decodeVideoFrames([original]).single;
        final after = decodeVideoFrames([compact]).single;
        expect(after.pixels, before.pixels);
        expect(after.detail!.pixels, before.detail!.pixels);
        expect(after.colorImage, before.colorImage);
        expect(after.sourceAspectRatio, before.sourceAspectRatio);
        expect(after.timestampUs, before.timestampUs);
        expect(after.sequence, before.sequence);
        expect(compact.ageUs, 23000);
        expect(
          compact.rgb.length + compact.gray!.length,
          lessThan(original.rgb.length),
        );
      },
    );
  }
  test('Invalid compact frames are rejected before pixel indexing', () {
    final valid = <String, Object>{
      'cameraId': 1,
      'timestampUs': 1,
      'sequence': 1,
      'width': 4,
      'height': 4,
      'colorWidth': 2,
      'colorHeight': 2,
      'rgb': Uint8List(12),
      'gray': Uint8List(16),
    };
    expect(
      () => CameraVideoFrame.fromMap({...valid, 'gray': Uint8List(15)}),
      throwsFormatException,
    );
    expect(
      () => CameraVideoFrame.fromMap({...valid, 'gray': null}),
      throwsFormatException,
    );
    expect(
      () => CameraVideoFrame.fromMap({...valid, 'colorWidth': 0}),
      throwsFormatException,
    );
    expect(
      () => CameraVideoFrame.fromMap({...valid, 'rgb': Uint8List(11)}),
      throwsFormatException,
    );
  });
  test(
    'Native PNG passes through without encoding and keeps motion pixels',
    () {
      final png = Uint8List.fromList(
        img.encodePng(img.Image(width: 4, height: 4)),
      );
      final gray = Uint8List.fromList(List.generate(16, (i) => i));
      final map = <String, Object?>{
        'cameraId': 1,
        'timestampUs': 123,
        'sequence': 9,
        'width': 4,
        'height': 4,
        'colorWidth': 4,
        'colorHeight': 4,
        'rgb': Uint8List(0),
        'gray': gray,
        'colorImage': png,
        'colorEncodeUs': 14000,
      };
      final frame = CameraVideoFrame.fromMap(map);
      final decoded = decodeVideoFrames([frame]).single;
      expect(decoded.pixels, gray);
      expect(identical(decoded.colorImage, png), isTrue);
      expect(frame.colorEncodeUs, 14000);
      expect(
        () => CameraVideoFrame.fromMap({...map, 'gray': null}),
        throwsFormatException,
      );
      expect(
        () => CameraVideoFrame.fromMap({...map, 'colorImage': Uint8List(0)}),
        throwsFormatException,
      );
    },
  );
}
