import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dart_tournament_manager/features/autoscoring/application/autoscoring_controller.dart';
import 'package:dart_tournament_manager/features/autoscoring/data/autoscoring_storage.dart';
import 'package:dart_tournament_manager/features/autoscoring/data/automatic_calibration_service.dart';
import 'package:dart_tournament_manager/features/autoscoring/domain/automatic_board_calibration.dart';
import 'package:flutter/foundation.dart';
import 'package:dart_tournament_manager/features/autoscoring/domain/board_geometry.dart';

class _Cameras extends CameraPlatform {
  _Cameras(this.directory);
  final Directory directory;
  final events = StreamController<CameraInitializedEvent>.broadcast();
  final released = <int>[];
  final captures = <String>[];
  final configurations = <MediaSettings>[];
  int nextId = 0;
  int activeCaptures = 0, maxActiveCaptures = 0;
  bool dart = false;
  bool sharedCapturePath = false;
  int? corruptCamera;
  int? failCamera;
  Completer<int>? creation;
  @override
  Future<List<CameraDescription>> availableCameras() async => [
    for (var i = 0; i < 3; i++)
      const CameraDescription(
        name: 'USB',
        lensDirection: CameraLensDirection.external,
        sensorOrientation: 0,
      ),
  ];
  @override
  Future<int> createCameraWithSettings(
    CameraDescription description,
    MediaSettings? settings,
  ) async {
    configurations.add(settings!);
    if (nextId == failCamera) {
      throw CameraException('CameraAccessDenied', 'Denied');
    }
    return creation == null ? nextId++ : creation!.future;
  }

  @override
  Stream<CameraInitializedEvent> onCameraInitialized(int id) =>
      events.stream.where((e) => e.cameraId == id);
  @override
  Stream<CameraErrorEvent> onCameraError(int id) => const Stream.empty();
  @override
  Stream<CameraClosingEvent> onCameraClosing(int id) => const Stream.empty();
  @override
  Future<void> initializeCamera(
    int id, {
    ImageFormatGroup imageFormatGroup = ImageFormatGroup.unknown,
  }) async {
    events.add(
      CameraInitializedEvent(
        id,
        320,
        320,
        ExposureMode.auto,
        false,
        FocusMode.auto,
        false,
      ),
    );
  }

  @override
  Future<void> dispose(int id) async {
    released.add(id);
  }

  @override
  Future<XFile> takePicture(int id) async {
    activeCaptures++;
    maxActiveCaptures = max(maxActiveCaptures, activeCaptures);
    final picture = img.Image(width: 320, height: 320);
    if (sharedCapturePath) {
      img.fill(picture, color: img.ColorRgb8(id * 40, id * 40, id * 40));
    }
    if (dart) {
      for (var y = 1; y < 319; y++) {
        for (var x = 1; x < 319; x++) {
          final shaft = switch (id) {
            0 => x >= 100 && x <= 210 && (y - 82).abs() <= 2,
            1 => y >= 50 && y <= 180 && (x - 159).abs() <= 2,
            _ => x >= 100 && x <= 210 && (y - (x - 77)).abs() <= 2,
          };
          if (shaft) picture.setPixelRgb(x, y, 180, 180, 180);
        }
      }
    }
    final path = sharedCapturePath
        ? '${directory.path}/shared.png'
        : '${directory.path}/frame_${captures.length}.png';
    captures.add(path);
    await File(
      path,
    ).writeAsBytes(id == corruptCamera ? [1, 2, 3] : img.encodePng(picture));
    activeCaptures--;
    return XFile(path);
  }
}

class _AutomaticCalibration extends AutomaticCalibrationService {
  int calls = 0;
  int? fail;
  @override
  Future<AutomaticCalibrationResult> calibrate(Uint8List image) async {
    if (calls++ == fail) {
      throw CalibrationFailure(
        'Zahlenring nicht lesbar.',
        diagnostics: BoardDetectionDiagnostics(selectiveColors: false)
          ..bullCandidates = const [Point(.5, .5)],
      );
    }
    return AutomaticCalibrationResult(
      BoardCalibration(const [
        Point(.5, .1),
        Point(.9, .5),
        Point(.5, .9),
        Point(.1, .5),
      ]),
      8,
    );
  }
}

class _ReferenceCalibration extends _AutomaticCalibration
    implements ReferenceAutomaticCalibrationService {
  int references = 0;
  @override
  Future<AutomaticCalibrationResult> calibrateUsingReference(
    Uint8List target,
    Uint8List reference,
    BoardCalibration calibration,
  ) async {
    references++;
    return AutomaticCalibrationResult(calibration, 0);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    directory = Directory.systemTemp.createTempSync('autoscore_test_');
  });
  tearDown(() => directory.deleteSync(recursive: true));
  test(
    'An invalid capture preserves all last validated camera images',
    () async {
      final platform = _Cameras(directory);
      final c = AutoscoringController(
        platform: platform,
        calibrationService: _AutomaticCalibration(),
      );
      await c.discover();
      await c.connect([0, 1, 2]);
      final before = c.cameras.map((camera) => camera.snapshot).toList();
      platform.corruptCamera = 1;
      await c.arm();
      expect(c.status, contains('Referenzaufnahme fehlgeschlagen'));
      for (var i = 0; i < 3; i++) {
        expect(identical(before[i], c.cameras[i].snapshot), isTrue);
      }
      await c.stop();
      c.dispose();
    },
  );
  test(
    'Shared plugin filenames cannot mix camera images or delete another capture',
    () async {
      final platform = _Cameras(directory)..sharedCapturePath = true;
      final c = AutoscoringController(
        platform: platform,
        calibrationService: _AutomaticCalibration(),
      );
      await c.discover();
      await c.connect([0, 1, 2]);
      expect(c.cameras.length, 3);
      expect(platform.maxActiveCaptures, 1);
      for (var i = 0; i < 3; i++) {
        final snapshot = img.decodeImage(c.cameras[i].snapshot!);
        expect(snapshot, isNotNull);
        expect(snapshot!.getPixel(0, 0).r, i * 40);
      }
      expect(
        platform.captures.every((path) => !File(path).existsSync()),
        isTrue,
      );
      await c.stop();
      c.dispose();
    },
  );
  for (final fail in [null, 1]) {
    test('Automatic demo starts after calibration, failure=$fail', () async {
      final platform = _Cameras(directory);
      final service = _AutomaticCalibration()..fail = fail;
      final c = AutoscoringController(
        platform: platform,
        calibrationService: service,
      )..automaticCounting = true;
      await c.discover();
      await c.connect([0, 1, 2]);
      expect(platform.maxActiveCaptures, 1);
      expect(c.running, fail == null);
      if (fail != null) {
        expect(
          c.cameras.every((camera) => camera.emptyReference == null),
          isTrue,
        );
        service.fail = null;
        await c.autoCalibrate();
        expect(c.running, isTrue);
      }
      expect(
        c.cameras.every((camera) => camera.emptyReference != null),
        isTrue,
      );
      await c.stop();
      c.dispose();
      await platform.events.close();
    });
  }
  test(
    'An unreadable number ring can be aligned with a calibrated camera',
    () async {
      final platform = _Cameras(directory);
      final service = _ReferenceCalibration()..fail = 0;
      final controller = AutoscoringController(
        platform: platform,
        calibrationService: service,
      );
      await controller.discover();
      await controller.connect([0, 1, 2]);
      expect(service.references, 1);
      expect(controller.cameras.every((c) => c.calibration != null), isTrue);
      expect(controller.cameras.first.calibrationMessage, contains('Kamera 2'));
      expect((await AutoscoringStorage().load()).length, 3);
      await controller.stop();
      controller.dispose();
      await platform.events.close();
    },
  );
  test(
    'Three-camera synthetic capture detects T20 once and releases snapshots',
    () async {
      final platform = _Cameras(directory);
      final service = _AutomaticCalibration();
      final c = AutoscoringController(
        platform: platform,
        calibrationService: service,
      );
      await c.discover();
      await c.connect([0, 1, 2]);
      expect(c.cameras.length, 3);
      expect(
        platform.configurations.every((s) => s.enableAudio == false),
        isTrue,
      );
      expect(service.calls, 3);
      expect(c.cameras.every((camera) => camera.calibration != null), isTrue);
      final stored = await AutoscoringStorage().load();
      expect(stored.keys.toSet(), {'USB#0', 'USB#1', 'USB#2'});
      await c.arm();
      platform.dart = true;
      final detected = Completer<void>();
      void listener() {
        if (c.pending != null && !detected.isCompleted) detected.complete();
      }

      c.addListener(listener);
      await detected.future.timeout(const Duration(seconds: 15));
      final hit = c.pending!;
      expect(BoardGeometry.score(hit.point).label, 'T20');
      expect(c.running, isFalse);
      c.accept(BoardGeometry.score(hit.point));
      expect(c.throws.length, 1);
      await Future<void>.delayed(const Duration(seconds: 2));
      expect(
        c.pending,
        isNull,
        reason:
            'Confirmed shaft must become the reference, avoiding duplicate darts',
      );
      c.removeListener(listener);
      await c.stop();
      c.dispose();
      expect(platform.released, [0, 1, 2]);
      expect(
        platform.captures.every((path) => !File(path).existsSync()),
        isTrue,
      );
      await platform.events.close();
    },
  );
  test(
    'Partial connection failure releases previously opened cameras',
    () async {
      final platform = _Cameras(directory)..failCamera = 1;
      final c = AutoscoringController(platform: platform);
      await c.discover();
      await c.connect([0, 1, 2]);
      expect(c.cameras, isEmpty);
      expect(platform.released, [0]);
      expect(c.busy, isFalse);
      c.dispose();
      await platform.events.close();
    },
  );
  test('Duplicate camera selection does not create devices', () async {
    final platform = _Cameras(directory);
    final c = AutoscoringController(platform: platform);
    await c.discover();
    await c.connect([0, 0, 2]);
    expect(platform.configurations, isEmpty);
    expect(c.cameras, isEmpty);
    c.dispose();
    await platform.events.close();
  });
  test('Disposal during creation releases the late camera', () async {
    final platform = _Cameras(directory)..creation = Completer<int>();
    final c = AutoscoringController(platform: platform);
    await c.discover();
    final connecting = c.connect([0, 1, 2]);
    await Future<void>.delayed(Duration.zero);
    c.dispose();
    platform.creation!.complete(7);
    await connecting;
    expect(platform.released, [7]);
    await platform.events.close();
  });
  test('Unknown persistence schema is rejected', () async {
    SharedPreferences.setMockInitialValues({
      AutoscoringStorage.key: '{"version":99,"cameras":{}}',
    });
    expect(AutoscoringStorage().load(), throwsFormatException);
  });
  test(
    'One unclear camera blocks all scoring and preserves saved calibration',
    () async {
      final platform = _Cameras(directory),
          service = _AutomaticCalibration()..fail = 1;
      final c = AutoscoringController(
        platform: platform,
        calibrationService: service,
      );
      await c.discover();
      await c.connect([0, 1, 2]);
      expect(c.cameras.length, 3);
      expect(c.cameras.every((camera) => camera.calibration == null), isTrue);
      expect(c.cameras[1].calibrationMessage, contains('Zahlenring'));
      expect(c.cameras[1].diagnostics!.bullCandidates, isNotEmpty);
      expect(c.cameras[0].candidateCalibration, isNotNull);
      expect(await AutoscoringStorage().load(), isEmpty);
      await c.arm();
      expect(c.running, isFalse);
      service.fail = null;
      await c.autoCalibrate();
      expect(c.cameras.every((camera) => camera.calibration != null), isTrue);
      expect((await AutoscoringStorage().load()).length, 3);
      final preferences = await SharedPreferences.getInstance();
      final saved = preferences.getString(AutoscoringStorage.key);
      service.fail = service.calls + 1;
      await c.autoCalibrate();
      expect(c.cameras.every((camera) => camera.calibration == null), isTrue);
      expect(preferences.getString(AutoscoringStorage.key), saved);
      await c.stop();
      c.dispose();
      await platform.events.close();
    },
  );
}
