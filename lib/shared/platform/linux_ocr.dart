import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'linux_commands.dart';

class LinuxOcr {
  static List<Map<String, Object>> parseTsv(String tsv) {
    final words = <Map<String, Object>>[];
    for (final line in const LineSplitter().convert(tsv).skip(1)) {
      final cells = line.split('\t');
      if (cells.length < 12 || cells[0] != '5') continue;
      final text = cells.sublist(11).join('\t').trim();
      if (!RegExp(r'^\d{1,2}$').hasMatch(text)) continue;
      final box = cells.sublist(6, 10).map(int.tryParse).toList();
      if (box.any((v) => v == null || v < 0)) continue;
      words.add({
        'text': text,
        'x': box[0]!,
        'y': box[1]!,
        'width': box[2]!,
        'height': box[3]!,
        'textAngle': 0,
      });
    }
    return words;
  }

  static Future<List<dynamic>> recognize(Map<String, Object> input) async {
    final width = input['width'] as int, height = input['height'] as int;
    final bgra = input['pixels'] as Uint8List;
    if (width <= 0 ||
        height <= 0 ||
        width * height > 20000000 ||
        bgra.length != width * height * 4) {
      throw const FormatException('Ungültiges OCR-Bild.');
    }
    final directory = await Directory.systemTemp.createTemp('dart-ocr-');
    try {
      final header = ascii.encode('P6\n$width $height\n255\n');
      final ppm = Uint8List(header.length + width * height * 3)
        ..setAll(0, header);
      for (var i = 0; i < width * height; i++) {
        ppm[header.length + i * 3] = bgra[i * 4 + 2];
        ppm[header.length + i * 3 + 1] = bgra[i * 4 + 1];
        ppm[header.length + i * 3 + 2] = bgra[i * 4];
      }
      final file = File('${directory.path}/numbers.ppm');
      await file.writeAsBytes(ppm);
      final result = await linuxCommand('tesseract', [
        file.path,
        'stdout',
        '-l',
        'eng',
        '--psm',
        '11',
        '-c',
        'tessedit_char_whitelist=0123456789',
        'tsv',
      ]);
      return parseTsv(utf8.decode(result.stdout as List<int>));
    } finally {
      await directory.delete(recursive: true);
    }
  }
}
