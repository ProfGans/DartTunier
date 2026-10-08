import 'package:flutter/services.dart';
import '../domain/video_frame_synchronizer.dart';

class WindowsVideoSource {
  WindowsVideoSource({
    this.channel = const MethodChannel('dart_tournament/autoscore_video'),
  });
  final MethodChannel channel;
  VideoFrameSynchronizer? synchronizer;
  bool active = false;
  int backlogDropped = 0;
  int oldestBufferedAgeUs = 0, newestBufferedAgeUs = 0;
  double readMilliseconds = 0;
  int readPixelBytes = 0;
  final _droppedByCamera = <int, int>{};
  int get nativeDropped =>
      _droppedByCamera.values.fold(0, (sum, count) => sum + count);
  Future<bool> configure(List<int> cameraIds) async {
    _droppedByCamera.clear();
    backlogDropped = 0;
    try {
      active =
          await channel.invokeMethod<bool>('configure', cameraIds) ?? false;
      synchronizer = active ? VideoFrameSynchronizer(List.of(cameraIds)) : null;
    } on MissingPluginException {
      active = false;
    }
    return active;
  }

  Future<List<List<CameraVideoFrame>>> read() async {
    if (!active || synchronizer == null) return [];
    final watch = Stopwatch()..start();
    final raw = await channel.invokeListMethod<Object?>('read') ?? [];
    readMilliseconds = watch.elapsedMicroseconds / 1000;
    readPixelBytes = raw.cast<Map>().fold<int>(
      0,
      (sum, m) =>
          sum +
          (m['rgb'] as Uint8List).length +
          ((m['gray'] as Uint8List?)?.length ?? 0) +
          ((m['colorImage'] as Uint8List?)?.length ?? 0),
    );
    final ages = raw
        .cast<Map>()
        .map((m) => m['ageUs'])
        .whereType<int>()
        .toList();
    if (ages.isNotEmpty) {
      ages.sort();
      newestBufferedAgeUs = ages.first;
      oldestBufferedAgeUs = ages.last;
    }
    for (final map in raw.cast<Map>()) {
      final frame = CameraVideoFrame.fromMap(map);
      synchronizer!.add(frame);
      _droppedByCamera[frame.cameraId] = frame.dropped;
    }
    final batches = <List<CameraVideoFrame>>[];
    List<CameraVideoFrame>? next;
    while ((next = synchronizer!.take()) != null) {
      batches.add(next!);
    }
    // Keep three independent observations for temporal/bounce confirmation,
    // but never spend another capture cycle draining a stale six-frame queue.
    if (batches.length > 3) {
      backlogDropped += batches.length - 3;
      batches.removeRange(0, batches.length - 3);
    }
    return batches;
  }

  Future<void> close() async {
    try {
      if (active) {
        await channel.invokeMethod<bool>('configure', <int>[]);
      }
    } on PlatformException {
      // Camera disposal also removes native queues if the channel already closed.
    } on MissingPluginException {
      // Closing an unavailable plugin must not prevent camera disposal.
    } finally {
      active = false;
      synchronizer?.clear();
    }
  }
}
