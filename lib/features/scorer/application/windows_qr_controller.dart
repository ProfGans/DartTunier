import 'dart:async';
import 'dart:io';
import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:flutter/foundation.dart';
import 'qr_image_decoder.dart';

/// Serializes camera access, including switching, backgrounding and disposal.
class WindowsQrController extends ChangeNotifier {
  WindowsQrController({CameraPlatform? platform})
    : platform = platform ?? CameraPlatform.instance;
  final CameraPlatform platform;
  List<CameraDescription> cameras = [];
  int selected = 0;
  int? cameraId;
  double aspectRatio = 4 / 3;
  bool ready = false, busy = false;
  String? error, result;
  bool _disposed = false;
  int _generation = 0;
  Timer? _timer;
  StreamSubscription<CameraErrorEvent>? _errors;
  StreamSubscription<CameraClosingEvent>? _closing;
  Future<void> _pending = Future.value();

  Future<void> _enqueue(Future<void> Function() action) {
    final next = _pending.then((_) => action());
    _pending = next.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return next;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> start({int? index}) {
    final generation = ++_generation;
    _timer?.cancel();
    busy = true;
    error = null;
    result = null;
    _notify();
    return _enqueue(() async {
      await _release();
      if (_disposed || generation != _generation) return;
      StreamSubscription<CameraInitializedEvent>? initializing;
      try {
        cameras = await platform.availableCameras();
        if (_disposed || generation != _generation) return;
        if (cameras.isEmpty) {
          throw StateError(
            'Keine Webcam gefunden. Bitte eine Kamera anschließen.',
          );
        }
        selected = (index ?? selected).clamp(0, cameras.length - 1);
        cameraId = await platform.createCameraWithSettings(
          cameras[selected],
          const MediaSettings(
            resolutionPreset: ResolutionPreset.high,
            enableAudio: false,
          ),
        );
        if (_disposed || generation != _generation) return;
        final initialized = Completer<CameraInitializedEvent>();
        initializing = platform.onCameraInitialized(cameraId!).listen((event) {
          if (!initialized.isCompleted) initialized.complete(event);
        });
        // Attach error handling before initialization to cover denied/in-use devices.
        final eventResult = initialized.future.timeout(
          const Duration(seconds: 15),
        );
        _errors = platform.onCameraError(cameraId!).listen((event) {
          if (!initialized.isCompleted) {
            initialized.completeError(
              StateError('Kamera konnte nicht geöffnet werden.'),
            );
          } else {
            _cameraFailed();
          }
        });
        _closing = platform
            .onCameraClosing(cameraId!)
            .listen((_) => _cameraFailed());
        await Future.wait([
          platform.initializeCamera(cameraId!),
          eventResult.then((event) {
            if (event.previewWidth > 0 && event.previewHeight > 0) {
              aspectRatio = event.previewWidth / event.previewHeight;
            }
          }),
        ]).timeout(const Duration(seconds: 16));
        if (_disposed || generation != _generation) return;
        ready = true;
        _schedule(generation);
      } catch (e) {
        error = cameras.isEmpty && e is StateError
            ? e.message.toString()
            : 'Kamera nicht verfügbar. Kamerazugriff erlauben und andere Kamera-Apps schließen. Unter Linux FFmpeg, v4l2-ctl und die Berechtigung für /dev/video prüfen.';
        await _release();
      } finally {
        await initializing?.cancel();
        if (_disposed || generation != _generation) await _release();
        if (generation == _generation) busy = false;
        _notify();
      }
    });
  }

  void _cameraFailed() {
    error = 'Die Kamera wurde getrennt oder ist nicht mehr verfügbar.';
    unawaited(stop());
  }

  void _schedule(int generation) {
    _timer = Timer(const Duration(milliseconds: 700), () {
      unawaited(
        _enqueue(() async {
          if (_disposed || !ready || generation != _generation) return;
          try {
            final capture = await platform.takePicture(cameraId!);
            late Uint8List bytes;
            // The Windows plugin creates a temporary snapshot, never a gallery photo.
            try {
              bytes = await capture.readAsBytes();
            } finally {
              await File(capture.path).delete();
            }
            if (_disposed || generation != _generation) return;
            final value = await compute(decodeQrImage, bytes);
            if (_disposed || generation != _generation) return;
            if (value != null) {
              result = value;
              _notify();
            }
          } catch (_) {
            if (generation == _generation) {
              error =
                  'Das Kamerabild konnte nicht gelesen werden. Bitte die Kamera erneut öffnen.';
              await _release();
              _notify();
            }
          }
          if (!_disposed && ready && generation == _generation) {
            _schedule(generation);
          }
        }),
      );
    });
  }

  Future<void> _release() async {
    ready = false;
    _timer?.cancel();
    await _errors?.cancel();
    _errors = null;
    await _closing?.cancel();
    _closing = null;
    final id = cameraId;
    cameraId = null;
    if (id != null) {
      try {
        await platform.dispose(id);
      } catch (_) {
        /* Device may already have disconnected. */
      }
    }
  }

  Future<void> stop() {
    ++_generation;
    _timer?.cancel();
    ready = false;
    busy = false;
    _notify();
    return _enqueue(_release);
  }

  @override
  void dispose() {
    _disposed = true;
    ++_generation;
    _timer?.cancel();
    unawaited(_enqueue(_release));
    super.dispose();
  }
}

