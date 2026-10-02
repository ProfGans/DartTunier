import 'dart:convert';
import 'package:file_selector/file_selector.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:dart_tournament_manager/shared/images/profile_image_picker.dart';

// Also runnable with flutter test --platform chrome; no native app database.
void main() {
  test('shared image import works without a native filesystem using XFile bytes', () async {
    final png = img.encodePng(img.Image(width: 40, height: 80));
    final picker = ProfileImagePicker(
      selectFile: () async =>
          XFile.fromData(png, name: 'profil.png', mimeType: 'image/png'),
    );
    final result = await picker.pick();
    final image = img.decodeJpg(base64Decode(result!))!;
    expect(image.width, 256);
    expect(image.height, 256);
    expect(
      await ProfileImagePicker(selectFile: () async => null).pick(),
      isNull,
    );
  });
}
