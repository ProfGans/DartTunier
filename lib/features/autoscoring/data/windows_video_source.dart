import 'package:flutter/services.dart';
import '../domain/video_frame_synchronizer.dart';

class WindowsVideoSource {
  WindowsVideoSource({
    this.channel = const MethodChannel('dart_tournament/autoscore_video'),
  });
  final MethodChannel channel;
  VideoFrameSynchronizer? synchronizer;
  bool active = false;
  final _droppedByCamera = <int, int>{};
  int get nativeDropped =>
      _droppedByCamera.values.fold(0, (sum, count) => sum + count);
  Future<bool> configure(List<int> cameraIds) async {
    _droppedByCamera.clear();
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
    final raw = await channel.invokeListMethod<Object?>('read') ?? [];
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
