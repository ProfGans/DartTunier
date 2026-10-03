import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:dart_tournament_manager/shared/persistence/app_data_directory.dart';
import 'package:dart_tournament_manager/shared/platform/mjpeg_frames.dart';
import 'package:dart_tournament_manager/shared/platform/linux_camera.dart';
import 'package:dart_tournament_manager/shared/platform/linux_ocr.dart';
import 'package:dart_tournament_manager/shared/platform/linux_commands.dart';
import 'package:dart_tournament_manager/features/notifications/data/linux_notification_service.dart';

class _CameraProcess implements Process {
  final output = StreamController<List<int>>();
  final done = Completer<int>();
  bool killed = false;
  @override
  Stream<List<int>> get stdout => output.stream;
  @override
  Stream<List<int>> get stderr => const Stream.empty();
  @override
  Future<int> get exitCode => done.future;
  @override
  int get pid => 999;
  @override
  IOSink get stdin => throw UnimplementedError();
  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) {
    killed = true;
    if (!done.isCompleted) {
      done.complete(0);
      output.close();
    }
    return true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'Linux data path works without APPDATA and preserves existing legacy data',
    () async {
      final temp = await Directory.systemTemp.createTemp('linux-storage-');
      addTearDown(() => temp.delete(recursive: true));
      final support = Directory(p.join(temp.path, 'xdg'));
      Future<Directory> resolve(Map<String, String> env) => appDataDirectory(
        operatingSystem: 'linux',
        environment: env,
        supportDirectory: () async => support,
      );
      expect((await resolve({})).path, support.path);
      expect((await resolve({'APPDATA': temp.path})).path, support.path);
      final legacy = Directory(p.join(temp.path, 'DartTournamentManager'));
      await legacy.create();
      await File(
        p.join(legacy.path, 'app_database.sqlite'),
      ).writeAsString('existing');
      expect((await resolve({'APPDATA': temp.path})).path, legacy.path);
      expect(
        (await appDataDirectory(
          operatingSystem: 'windows',
          environment: {'APPDATA': temp.path},
        )).path,
        legacy.path,
      );
      await expectLater(
        appDataDirectory(operatingSystem: 'windows', environment: {}),
        throwsStateError,
      );
    },
  );
  test(
    'MJPEG framing handles chunk boundaries, multiple frames and bounded memory',
    () {
      final parser = MjpegFrames(limit: 20);
      expect(parser.add([1, 255]), isEmpty);
      expect(parser.add([216, 3, 255]), isEmpty);
      expect(parser.add([217, 255, 216, 4, 255, 217]), [
        [255, 216, 3, 255, 217],
        [255, 216, 4, 255, 217],
      ]);
      expect(
        () => parser.add([255, 216, ...List.filled(21, 0)]),
        throwsFormatException,
      );
    },
  );
  test(
    'Tesseract TSV maps word rectangles and ignores malformed/non-numeric text',
    () {
      final result = LinuxOcr.parseTsv(
        'header\n5\t1\t1\t1\t1\t1\t10\t20\t30\t40\t90\t20\n'
        '5\t1\t1\t1\t1\t1\t0\t0\t1\t1\t90\tnoise\ninvalid',
      );
      expect(result, [
        {
          'text': '20',
          'x': 10,
          'y': 20,
          'width': 30,
          'height': 40,
          'textAngle': 0,
        },
      ]);
    },
  );
  test(
    'camera emits initialization, snapshots and releases its process and temporary files',
    () async {
      final process = _CameraProcess();
      final camera = LinuxCamera(
        startProcess: (exe, args) async {
          expect(exe, 'ffmpeg');
          expect(args, contains('/dev/video0'));
          return process;
        },
      );
      const description = CameraDescription(
        name: '/dev/video0',
        lensDirection: CameraLensDirection.external,
        sensorOrientation: 0,
      );
      final id = await camera.createCameraWithSettings(
        description,
        const MediaSettings(enableAudio: false),
      );
      final initialized = camera.onCameraInitialized(id).first;
      final starting = camera.initializeCamera(id);
      process.output.add(img.encodeJpg(img.Image(width: 32, height: 24)));
      await starting;
      expect((await initialized).previewWidth, 32);
      final file = await camera.takePicture(id);
      expect(img.decodeJpg(await file.readAsBytes())!.height, 24);
      await camera.dispose(id);
      expect(process.killed, isTrue);
      expect(await File(file.path).exists(), isFalse);
      await expectLater(camera.takePicture(id), throwsStateError);
    },
  );
  test('systemd arguments escape spaces, specifiers and newlines', () {
    expect(LinuxNotificationService.systemdQuote(r'/home/$USER/app'), r'"/home/$$USER/app"');
    expect(
      LinuxNotificationService.systemdQuote('/home/A B/100%/"x"\n'),
      '"/home/A B/100%%/\\"x\\"\\n"',
    );
  });
  if (Platform.isLinux) {
    test(
      'installed Linux tools generate camera-compatible JPEG and recognize board numbers',
      () async {
        final output = await linuxCommand('ffmpeg', [
          '-hide_banner',
          '-loglevel',
          'error',
          '-f',
          'lavfi',
          '-i',
          'color=c=white:s=64x48',
          '-frames:v',
          '1',
          '-f',
          'image2pipe',
          '-vcodec',
          'mjpeg',
          'pipe:1',
        ]);
        expect(
          img.decodeJpg(Uint8List.fromList(output.stdout as List<int>))!.width,
          64,
        );
        final picture = img.Image(width: 200, height: 100);
        img.fill(picture, color: img.ColorRgb8(255, 255, 255));
        img.drawString(
          picture,
          '20',
          font: img.arial48,
          x: 30,
          y: 20,
          color: img.ColorRgb8(0, 0, 0),
        );
        final words = await LinuxOcr.recognize({
          'width': 200,
          'height': 100,
          'pixels': picture.getBytes(order: img.ChannelOrder.bgra),
        });
        expect(words.any((w) => w['text'] == '20'), isTrue);
      },
    );
  }
}
