import 'dart:collection';
import 'dart:typed_data';

class CameraVideoFrame {
  const CameraVideoFrame(
    this.cameraId,
    this.timestampUs,
    this.sequence,
    this.width,
    this.height,
    this.rgb, {
    this.dropped = 0,
    this.ageUs = 0,
    this.gray,
    this.colorWidth,
    this.colorHeight,
    this.colorImage,
    this.colorEncodeUs = 0,
  });
  final int cameraId, timestampUs, sequence, width, height, dropped;
  final int ageUs;
  final Uint8List rgb;
  final Uint8List? gray;
  final int? colorWidth, colorHeight;
  final Uint8List? colorImage;
  final int colorEncodeUs;
  int get rgbWidth => colorWidth ?? width;
  int get rgbHeight => colorHeight ?? height;
  factory CameraVideoFrame.fromMap(Map map) {
    final frame = CameraVideoFrame(
      map['cameraId'] as int,
      map['timestampUs'] as int,
      map['sequence'] as int,
      map['width'] as int,
      map['height'] as int,
      map['rgb'] as Uint8List,
      dropped: map['dropped'] as int? ?? 0,
      ageUs: map['ageUs'] as int? ?? 0,
      gray: map['gray'] as Uint8List?,
      colorWidth: map['colorWidth'] as int?,
      colorHeight: map['colorHeight'] as int?,
      colorImage: map['colorImage'] as Uint8List?,
      colorEncodeUs: map['colorEncodeUs'] as int? ?? 0,
    );
    if (frame.width < 1 ||
        frame.height < 1 ||
        frame.width > 1280 ||
        frame.height > 2160 ||
        frame.rgbWidth < 1 ||
        frame.rgbWidth > 1280 ||
        frame.rgbHeight < 1 ||
        frame.rgbHeight > 2160 ||
        (frame.colorImage == null &&
            frame.rgb.length != frame.rgbWidth * frame.rgbHeight * 3) ||
        (frame.colorImage != null &&
            (frame.gray == null ||
                frame.colorImage!.isEmpty ||
                frame.colorImage!.length > 16 * 1024 * 1024)) ||
        (frame.gray != null &&
            frame.gray!.length != frame.width * frame.height) ||
        (frame.gray == null &&
            (frame.rgbWidth != frame.width ||
                frame.rgbHeight != frame.height))) {
      throw const FormatException('Ungültiger Video-Frame');
    }
    return frame;
  }
}

/// Timestamp matching is approximate host-arrival synchronization, not hardware
/// triggering. Old/duplicate frames never become an independent observation.
class VideoFrameSynchronizer {
  VideoFrameSynchronizer(this.cameraIds, {this.maxSkewUs = 40000});
  final List<int> cameraIds;
  final int maxSkewUs;
  final _queues = <int, Queue<CameraVideoFrame>>{};
  final _lastSequence = <int, int>{};
  int discarded = 0, lastSkewUs = 0;
  void add(CameraVideoFrame frame) {
    if (!cameraIds.contains(frame.cameraId) ||
        frame.sequence <= (_lastSequence[frame.cameraId] ?? -1)) {
      return;
    }
    _lastSequence[frame.cameraId] = frame.sequence;
    final queue = _queues.putIfAbsent(frame.cameraId, Queue.new);
    queue.add(frame);
    if (queue.length > 6) {
      queue.removeFirst();
      discarded++;
    }
  }

  List<CameraVideoFrame>? take() {
    if (cameraIds.length != 3) return null;
    while (cameraIds.every((id) => _queues[id]?.isNotEmpty ?? false)) {
      final heads = [for (final id in cameraIds) _queues[id]!.first];
      final times = heads.map((f) => f.timestampUs).toList()..sort();
      if (times.last - times.first <= maxSkewUs) {
        lastSkewUs = times.last - times.first;
        return [for (final id in cameraIds) _queues[id]!.removeFirst()];
      }
      _queues[heads.firstWhere((f) => f.timestampUs == times.first).cameraId]!
          .removeFirst();
      discarded++;
    }
    return null;
  }

  void clear() {
    _queues.clear();
    _lastSequence.clear();
  }
}
