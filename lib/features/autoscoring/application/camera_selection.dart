import 'package:camera_platform_interface/camera_platform_interface.dart';

/// Prefer USB/UVC devices, then other physical external cameras. Windows
/// exposes names rather than a reliable USB transport flag, so keep unknown
/// devices available as a fallback and allow manual selection.
List<int> preferredAutoscoreCameras(List<CameraDescription> cameras) {
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
  return List<int>.generate(3, (i) => i < indices.length ? indices[i] : -1);
}
