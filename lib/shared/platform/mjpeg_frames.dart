import 'dart:typed_data';

/// FFmpeg's image2pipe emits standalone JPEGs, potentially across pipe chunks.
class MjpegFrames {
  final int limit;
  MjpegFrames({this.limit = 8 * 1024 * 1024});
  final _bytes = <int>[];
  bool _inside = false;
  int _previous = -1;
  List<Uint8List> add(List<int> chunk) {
    final frames = <Uint8List>[];
    for (final byte in chunk) {
      if (!_inside) {
        if (_previous == 255 && byte == 216) {
          _inside = true;
          _bytes.addAll([255, 216]);
        }
      } else {
        _bytes.add(byte);
        if (_bytes.length > limit) {
          _bytes.clear();
          _inside = false;
          throw const FormatException('Kamerabild zu groß.');
        }
        if (_previous == 255 && byte == 217) {
          frames.add(Uint8List.fromList(_bytes));
          _bytes.clear();
          _inside = false;
        }
      }
      _previous = byte;
    }
    return frames;
  }
}
