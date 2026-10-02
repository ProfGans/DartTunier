import 'dart:typed_data';
import 'package:file_selector/file_selector.dart';
import 'profile_image_encoder.dart';

typedef ProfileImageSelection = Future<XFile?> Function();

/// One bounded import path for community and personal profiles on all platforms.
class ProfileImagePicker {
  const ProfileImagePicker({
    this.selectFile = _selectFile,
    this.encode = encodeProfileImage,
  });
  final ProfileImageSelection selectFile;
  final Future<String> Function(Uint8List) encode;
  static const maxBytes = 5 * 1024 * 1024;
  static const types = XTypeGroup(
    label: 'Profilbild (JPG, PNG, WebP)',
    extensions: ['jpg', 'jpeg', 'png', 'webp'],
    mimeTypes: ['image/jpeg', 'image/png', 'image/webp'],
    uniformTypeIdentifiers: [
      'public.jpeg',
      'public.png',
      'org.webmproject.webp',
    ],
  );
  static bool _dialogOpen = false;
  static Future<XFile?> _selectFile() async {
    if (_dialogOpen) return null;
    _dialogOpen = true;
    try {
      return await openFile(acceptedTypeGroups: [types]);
    } finally {
      _dialogOpen = false;
    }
  }

  Future<String?> pick() async {
    final file = await selectFile();
    if (file == null) return null;
    if (await file.length() > maxBytes) {
      throw const FormatException('Bitte ein Bild bis 5 MB auswählen.');
    }
    // Bound the actual read as well: a file may change after length() is read.
    final data = BytesBuilder(copy: false);
    await for (final chunk in file.openRead()) {
      if (data.length + chunk.length > maxBytes) {
        throw const FormatException('Bitte ein Bild bis 5 MB auswählen.');
      }
      data.add(chunk);
    }
    return encode(data.takeBytes());
  }
}
