import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:qr_flutter/qr_flutter.dart';
import 'package:dart_tournament_manager/features/scorer/application/qr_image_decoder.dart';
import 'package:dart_tournament_manager/features/scorer/application/windows_qr_controller.dart';
import 'package:dart_tournament_manager/features/scorer/domain/scorer_lobby.dart';
import 'package:dart_tournament_manager/features/scorer/presentation/lobby/scorer_scanner_page.dart';
import 'package:dart_tournament_manager/features/scorer/presentation/lobby/scorer_join_page.dart';
import 'support/scorer_lobby_fake.dart';

Uint8List qrPicture(String text, {bool invert = false, bool rotate = false}) {
  final qr = QrImage(
    QrCode.fromData(data: text, errorCorrectLevel: QrErrorCorrectLevel.M),
  );
  const scale = 6, border = 4;
  final size = (qr.moduleCount + border * 2) * scale;
  var picture = img.Image(width: size, height: size);
  for (final p in picture) {
    final row = p.y ~/ scale - border, col = p.x ~/ scale - border;
    final dark =
        row >= 0 &&
        col >= 0 &&
        row < qr.moduleCount &&
        col < qr.moduleCount &&
        qr.isDark(row, col);
    final value = dark != invert ? 0 : 255;
    p.setRgb(value, value, value);
  }
  if (rotate) picture = img.copyRotate(picture, angle: 90);
  return img.encodePng(picture);
}

class _Camera extends CameraPlatform {
  final events = StreamController<CameraInitializedEvent>.broadcast();
  List<CameraDescription> cameras = const [
    CameraDescription(
      name: 'Webcam',
      lensDirection: CameraLensDirection.external,
      sensorOrientation: 0,
    ),
    CameraDescription(
      name: 'USB-Kamera',
      lensDirection: CameraLensDirection.external,
      sensorOrientation: 0,
    ),
  ];
  Completer<int>? creation;
  bool denied = false;
  int nextId = 1;
  final released = <int>[];
  final settings = <MediaSettings>[];
  String? imagePath;
  @override
  Future<List<CameraDescription>> availableCameras() async => cameras;
  @override
  Future<int> createCameraWithSettings(
    CameraDescription description,
    MediaSettings? config,
  ) async {
    settings.add(config!);
    if (denied) throw CameraException('CameraAccessDenied', 'Denied');
    return creation == null ? nextId++ : creation!.future;
  }

  @override
  Stream<CameraInitializedEvent> onCameraInitialized(int cameraId) =>
      events.stream.where((event) => event.cameraId == cameraId);
  @override
  Stream<CameraErrorEvent> onCameraError(int cameraId) => const Stream.empty();
  @override
  Stream<CameraClosingEvent> onCameraClosing(int cameraId) =>
      const Stream.empty();
  @override
  Future<void> initializeCamera(
    int cameraId, {
    ImageFormatGroup imageFormatGroup = ImageFormatGroup.unknown,
  }) async {
    events.add(
      CameraInitializedEvent(
        cameraId,
        640,
        480,
        ExposureMode.auto,
        false,
        FocusMode.auto,
        false,
      ),
    );
  }

  @override
  Future<void> dispose(int cameraId) async {
    released.add(cameraId);
  }

  @override
  Widget buildPreview(int cameraId) => const ColoredBox(
    color: Colors.black,
    child: Center(
      child: Text('Kameravorschau', style: TextStyle(color: Colors.white)),
    ),
  );
  @override
  Future<XFile> takePicture(int cameraId) async => XFile(imagePath!);
}

class _ViewController extends WindowsQrController {
  _ViewController(this.camera) : super(platform: camera);
  final _Camera camera;
  @override
  Future<void> start({int? index}) async {
    cameras = camera.cameras;
    selected = index ?? selected;
    cameraId = 1;
    ready = !camera.denied;
    busy = false;
    error = camera.denied
        ? 'Kamerazugriff gesperrt. Bitte den Zugriff für Desktop-Apps in den Windows-Einstellungen erlauben.'
        : null;
    notifyListeners();
  }
}

void main() {
  const previewFont = String.fromEnvironment('LAYOUT_PREVIEW_FONT');
  setUpAll(() async {
    if (previewFont.isNotEmpty) {
      await (FontLoader('Roboto')..addFont(
            File(
              previewFont,
            ).readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
          ))
          .load();
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    }
  });
  const code = '0123456789ABCDEF0123456789ABCDEF';
  final link = ScorerJoinCode.link(code);
  for (final variant in [(false, false), (true, false), (false, true)]) {
    test('Decode independent QR encoder, inversion/rotation $variant', () {
      expect(
        decodeQrImage(qrPicture(link, invert: variant.$1, rotate: variant.$2)),
        link,
      );
    });
  }
  test('Image without QR is ignored', () {
    expect(
      decodeQrImage(img.encodePng(img.Image(width: 100, height: 100))),
      isNull,
    );
    expect(decodeQrImage(Uint8List(0)), isNull);
  });
  test('Camera switching disables audio and releases old device', () async {
    final camera = _Camera();
    final controller = WindowsQrController(platform: camera);
    await controller.start();
    expect(controller.ready, true);
    expect(camera.settings.single.enableAudio, false);
    await controller.start(index: 1);
    expect(camera.released, [1]);
    expect(controller.selected, 1);
    await controller.stop();
    expect(camera.released, [1, 2]);
    controller.dispose();
    await camera.events.close();
  });
  test('Denied camera can be retried', () async {
    final camera = _Camera()..denied = true;
    final controller = WindowsQrController(platform: camera);
    await controller.start();
    expect(controller.busy, false);
    expect(controller.error, isNotNull);
    camera.denied = false;
    await controller.start();
    expect(controller.ready, true);
    expect(controller.error, isNull);
    await controller.stop();
    controller.dispose();
    await camera.events.close();
  });
  test('Disposal during camera creation releases the late device', () async {
    final camera = _Camera()..creation = Completer<int>();
    final controller = WindowsQrController(platform: camera);
    final starting = controller.start();
    await Future<void>.delayed(Duration.zero);
    controller.dispose();
    camera.creation!.complete(7);
    await starting;
    expect(camera.released, [7]);
    await camera.events.close();
  });
  test(
    'Camera snapshot decodes locally and its temporary file is deleted',
    () async {
      final directory = await Directory.systemTemp.createTemp('scorer_camera_');
      final file = File('${directory.path}/frame.png');
      await file.writeAsBytes(qrPicture(link));
      final camera = _Camera()..imagePath = file.path;
      final controller = WindowsQrController(platform: camera);
      final result = Completer<String>();
      controller.addListener(() {
        if (controller.result != null && !result.isCompleted) {
          result.complete(controller.result!);
        }
      });
      try {
        await controller.start();
        expect(await result.future.timeout(const Duration(seconds: 10)), link);
        expect(await file.exists(), false);
      } finally {
        await controller.stop();
        controller.dispose();
        await camera.events.close();
        await directory.delete(recursive: true);
      }
    },
  );
  for (final size in [
    const Size(360, 800),
    const Size(800, 600),
    const Size(1440, 900),
  ]) {
    testWidgets('Windows scanner and permission failure fit $size at 200%', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(tester.view.reset);
      final camera = _Camera()..denied = true;
      final control = _ViewController(camera);
      final previewKey = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            fontFamily: previewFont.isEmpty ? null : 'Roboto',
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF0D7A5F),
            ),
          ),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(2)),
            child: child!,
          ),
          home: RepaintBoundary(
            key: previewKey,
            child: ScorerScannerPage(windowsController: control),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final retry = find.text('Kamera erneut öffnen');
      await tester.scrollUntilVisible(
        retry,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      camera.denied = false;
      await Scrollable.ensureVisible(tester.element(retry), alignment: .5);
      await tester.pumpAndSettle();
      await tester.tap(retry);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        control.busy,
        false,
        reason:
            'id=${control.cameraId}, error=${control.error}, ready=${control.ready}',
      );
      expect(find.text('Kameravorschau'), findsOneWidget);
      expect(tester.takeException(), isNull);
      if (previewFont.isNotEmpty) {
        await tester.runAsync(() async {
          final boundary =
              previewKey.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          final picture = await boundary.toImage();
          final data = await picture.toByteData(format: ui.ImageByteFormat.png);
          final file = File(
            'build/layout_previews/scorer_camera_${size.width}.png',
          );
          await file.parent.create(recursive: true);
          await file.writeAsBytes(data!.buffer.asUint8List());
          picture.dispose();
        });
      }
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      expect(camera.released, [1]);
      await camera.events.close();
      debugDefaultTargetPlatformOverride = null;
    });
  }
  testWidgets('Windows join page offers in-app camera button', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    await tester.pumpWidget(
      MaterialApp(
        home: ScorerJoinPage(repository: FakeScorerLobbyRepository()),
      ),
    );
    expect(find.text('Kamera öffnen · QR scannen'), findsOneWidget);
    debugDefaultTargetPlatformOverride = null;
  });
}
