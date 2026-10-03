import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:flutter/widgets.dart';
import 'package:image/image.dart' as img;
import 'mjpeg_frames.dart';
import 'linux_commands.dart';

/// Shared V4L2 snapshot/preview adapter for autoscore and desktop QR scanning.
/// Each camera owns a persistent FFmpeg process, never a shell command.
class LinuxCamera extends CameraPlatform {
  LinuxCamera({Future<Process> Function(String, List<String>)? startProcess})
    : _startProcess = startProcess ?? ((exe, args) => Process.start(exe, args));
  final Future<Process> Function(String, List<String>) _startProcess;
  final _cameras = <int, _Capture>{};
  int _nextId = 0;
  @override
  Future<List<CameraDescription>> availableCameras() async {
    final devices = await Directory('/sys/class/video4linux').list().toList();
    devices.sort((a, b) => a.path.compareTo(b.path));
    final cameras = <CameraDescription>[];
    for (final entry in devices) {
      final device = '/dev/${entry.path.split('/').last}';
      if (!RegExp(r'^/dev/video\d+$').hasMatch(device)) continue;
      try {
        final result = await linuxCommand('v4l2-ctl', [
          '--device',
          device,
          '--all',
        ]);
        final cameraDescription = String.fromCharCodes(
          result.stdout as List<int>,
        );
        // Metadata-only V4L2 nodes cannot deliver pictures.
        final caps = cameraDescription
            .split('Device Caps')
            .last
            .split('Priority')
            .first;
        if (!caps.contains('Video Capture')) continue;
        cameras.add(
          CameraDescription(
            name: device,
            lensDirection: CameraLensDirection.external,
            sensorOrientation: 0,
          ),
        );
      } catch (_) {
        /* Permission denied or disconnected: skip this node. */
      }
    }
    return cameras;
  }

  @override
  Future<int> createCameraWithSettings(
    CameraDescription cameraDescription,
    MediaSettings mediaSettings,
  ) async {
    if (!RegExp(r'^/dev/video\d+$').hasMatch(cameraDescription.name)) {
      throw ArgumentError('Ungültiges Linux-Kameragerät.');
    }
    final cameraId = _nextId++;
    _cameras[cameraId] = _Capture(cameraDescription.name);
    return cameraId;
  }

  _Capture _get(int cameraId) =>
      _cameras[cameraId] ?? (throw StateError('Kamera bereits geschlossen.'));
  @override
  Stream<CameraInitializedEvent> onCameraInitialized(int cameraId) =>
      _get(cameraId).initialized.stream;
  @override
  Stream<CameraErrorEvent> onCameraError(int cameraId) =>
      _get(cameraId).errors.stream;
  @override
  Stream<CameraClosingEvent> onCameraClosing(int cameraId) =>
      _get(cameraId).closing.stream;

  @override
  Future<void> initializeCamera(
    int cameraId, {
    ImageFormatGroup imageFormatGroup = ImageFormatGroup.unknown,
  }) async {
    final capture = _get(cameraId);
    try {
      final process = await _startProcess('ffmpeg', [
        '-nostdin',
        '-hide_banner',
        '-loglevel',
        'error',
        '-f',
        'video4linux2',
        '-video_size',
        '1280x720',
        '-i',
        capture.device,
        '-an',
        '-vf',
        'fps=5',
        '-threads',
        '1',
        '-f',
        'image2pipe',
        '-vcodec',
        'mjpeg',
        '-q:v',
        '3',
        'pipe:1',
      ]);
      capture.process = process;
      final parser = MjpegFrames();
      final first = Completer<void>();
      void fail() {
        if (capture.disposed) return;
        capture.errors.add(
          CameraErrorEvent(
            cameraId,
            'Linux-Kamera nicht verfügbar. FFmpeg, V4L2-Zugriff und USB-Kamera prüfen.',
          ),
        );
        if (!first.isCompleted) {
          first.completeError(StateError('Kein Kamerabild.'));
        }
      }

      final ready = first.future.timeout(const Duration(seconds: 12));
      ready.ignore();
      capture.stdout = process.stdout.listen(
        (chunk) {
          if (capture.disposed) return;
          try {
            for (final frame in parser.add(chunk)) {
              capture.frame.value = frame;
              capture.received = DateTime.now();
              if (!first.isCompleted) {
                final decoded = img.decodeJpg(frame);
                if (decoded == null) continue;
                capture.initialized.add(
                  CameraInitializedEvent(
                    cameraId,
                    decoded.width.toDouble(),
                    decoded.height.toDouble(),
                    ExposureMode.auto,
                    false,
                    FocusMode.auto,
                    false,
                  ),
                );
                first.complete();
              }
            }
          } catch (_) {
            fail();
            process.kill();
          }
        },
        onError: (_) => fail(),
        onDone: fail,
      );
      capture.stderr = process.stderr.listen((_) {});
      await ready;
    } catch (_) {
      capture.process?.kill();
      rethrow;
    }
  }

  @override
  Future<XFile> takePicture(int cameraId) async {
    final capture = _get(cameraId);
    final frame = capture.frame.value;
    if (frame == null ||
        capture.received == null ||
        DateTime.now().difference(capture.received!) >
            const Duration(seconds: 3)) {
      throw StateError('Kein aktuelles Kamerabild.');
    }
    final directory = capture.snapshots ??= await Directory.systemTemp
        .createTemp('dart-camera-$cameraId-');
    final file = File('${directory.path}/${capture.serial++}.jpg');
    await file.writeAsBytes(frame);
    return XFile(file.path);
  }

  @override
  Widget buildPreview(int cameraId) => ValueListenableBuilder<Uint8List?>(
    valueListenable: _get(cameraId).frame,
    builder: (context, bytes, _) => bytes == null
        ? const SizedBox()
        : Image.memory(bytes, gaplessPlayback: true, fit: BoxFit.contain),
  );

  @override
  Future<void> dispose(int cameraId) async {
    final capture = _cameras.remove(cameraId);
    if (capture == null) return;
    capture.disposed = true;
    capture.process?.kill();
    await capture.stdout?.cancel();
    await capture.stderr?.cancel();
    if (capture.process != null) {
      try {
        await capture.process!.exitCode.timeout(const Duration(seconds: 2));
      } on TimeoutException {
        capture.process!.kill(ProcessSignal.sigkill);
      }
    }
    await capture.initialized.close();
    await capture.errors.close();
    await capture.closing.close();
    // Own private temporary directory only; never a user-provided path.
    if (capture.snapshots != null) {
      await capture.snapshots!.delete(recursive: true);
    }
    capture.frame.dispose();
  }
}

class _Capture {
  _Capture(this.device);
  final String device;
  final frame = ValueNotifier<Uint8List?>(null);
  final initialized = StreamController<CameraInitializedEvent>.broadcast();
  final errors = StreamController<CameraErrorEvent>.broadcast();
  final closing = StreamController<CameraClosingEvent>.broadcast();
  Process? process;
  StreamSubscription<List<int>>? stdout, stderr;
  DateTime? received;
  Directory? snapshots;
  int serial = 0;
  bool disposed = false;
}
