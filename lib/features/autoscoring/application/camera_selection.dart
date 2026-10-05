import 'package:camera_platform_interface/camera_platform_interface.dart';

/// Prefer USB/UVC devices, then other physical external cameras. Windows
/// exposes names rather than a reliable USB transport flag, so keep unknown
/// devices available as a fallback and allow manual selection.
String autoscoreCameraKey(List<CameraDescription> cameras, int index) =>
    '${cameras[index].name}#${cameras.take(index).where((c) => c.name == cameras[index].name).length}';

List<int> preferredAutoscoreCameras(
  List<CameraDescription> cameras, {
  List<String> preferred = const [],
}) {
  int priority(CameraDescription camera) {
    final name = camera.name.toLowerCase();
    if (RegExp(
      r'virtual|obs|manycam|snap camera|droidcam|iriun',
    ).hasMatch(name)) {
      return 3;
    }
    if (RegExp(r'usb|uvc|vid_').hasMatch(name)) return 0;
    if (RegExp(r'integrated|built.in|internal|facetime').hasMatch(name)) {
      return 2;
    }
    return camera.lensDirection == CameraLensDirection.external ? 1 : 2;
  }

  final indices = List<int>.generate(cameras.length, (i) => i);
  indices.sort((a, b) {
    final order = priority(cameras[a]).compareTo(priority(cameras[b]));
    return order == 0 ? a.compareTo(b) : order;
  });
  final saved = <int>[];
  for (final key in preferred.take(3)) {
    final index = List.generate(cameras.length, (i) => i).firstWhere(
      (i) => autoscoreCameraKey(cameras, i) == key,
      orElse: () => -1,
    );
    if (index >= 0 && !saved.contains(index)) saved.add(index);
  }
  indices.removeWhere(saved.contains);
  indices.insertAll(0, saved);
  return List<int>.generate(3, (i) => i < indices.length ? indices[i] : -1);
}
