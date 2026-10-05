import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:dart_tournament_manager/features/autoscoring/application/camera_selection.dart';
import 'package:flutter_test/flutter_test.dart';

CameraDescription camera(String name) => CameraDescription(
  name: name,
  lensDirection: CameraLensDirection.external,
  sensorOrientation: 0,
);

void main() {
  test(
    'Setup camera order survives enumeration changes and missing devices',
    () {
      final cameras = [
        camera('Integrated Camera'),
        camera('USB'),
        camera('USB'),
        camera('Dart'),
      ];
      expect(
        preferredAutoscoreCameras(
          cameras,
          preferred: ['USB#1', 'Dart#0', 'USB#0'],
        ),
        [2, 3, 1],
      );
      expect(
        preferredAutoscoreCameras(cameras, preferred: ['Absent#0', 'USB#1']),
        [2, 1, 3],
      );
      expect(autoscoreCameraKey(cameras, 2), 'USB#1');
    },
  );
  test(
    'Three USB cameras take precedence over built-in and virtual cameras',
    () {
      expect(
        preferredAutoscoreCameras([
          camera('Integrated Camera'),
          camera('OBS Virtual USB Camera'),
          camera('USB Camera'),
          camera('UVC Camera'),
          camera(r'camera#vid_1234'),
        ]),
        [2, 3, 4],
      );
    },
  );
  test('Identically named USB cameras remain three distinct devices', () {
    expect(
      preferredAutoscoreCameras([
        camera('Integrated Camera'),
        camera('USB Camera'),
        camera('USB Camera'),
        camera('USB Camera'),
      ]),
      [1, 2, 3],
    );
  });
  test('Unknown physical devices are used before virtual cameras', () {
    expect(
      preferredAutoscoreCameras([
        camera('OBS Virtual Camera'),
        camera('Dart camera'),
        camera('USB Camera'),
      ]),
      [2, 1, 0],
    );
  });
  test('Missing devices are left unselected', () {
    expect(preferredAutoscoreCameras([]), [-1, -1, -1]);
    expect(preferredAutoscoreCameras([camera('USB Camera')]), [0, -1, -1]);
  });
}
