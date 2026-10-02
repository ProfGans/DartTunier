import 'dart:async';
import 'dart:io';
import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:flutter/foundation.dart';
import '../data/autoscoring_storage.dart';
import '../data/automatic_calibration_service.dart';
import '../domain/automatic_board_calibration.dart';
import '../domain/board_geometry.dart';
import '../domain/frame_detector.dart';
import '../domain/automatic_visit_reset.dart';
import '../domain/automatic_bounce_detector.dart';
import '../../scorer/domain/x01/x01_models.dart';

class AutoscoreCamera {
  AutoscoreCamera(
    this.description,
    this.id,
    this.aspectRatio, {
    this.deviceIndex = 0,
  });
  final CameraDescription description;
  final int id;
  final double aspectRatio;
  final int deviceIndex;
  String get calibrationKey => '${description.name}#$deviceIndex';
  BoardCalibration? calibration;
  BoardCalibration? candidateCalibration;
  BoardDetectionDiagnostics? diagnostics;
  DartAxis? detectedAxis, lastAcceptedAxis;
  List<BoardPoint> changedPixels = const [];
  double changeFraction = 0;
  GrayFrame? reference, previous, emptyReference;
  GrayFrame? lastReference;
  Uint8List? snapshot;
  double? snapshotAspectRatio;
  int stable = 0;
  String? calibrationMessage;
}

/// Snapshot polling is used because camera_windows has no image stream.
/// All camera mutations and captures run through a single queue.
class AutoscoringController extends ChangeNotifier {
  AutoscoringController({
    CameraPlatform? platform,
    AutoscoringStorage? storage,
    AutomaticCalibrationService? calibrationService,
  }) : platform = platform ?? CameraPlatform.instance,
       storage = storage ?? AutoscoringStorage(),
       calibrationService =
           calibrationService ?? const WindowsAutomaticCalibrationService();
  final CameraPlatform platform;
  final AutoscoringStorage storage;
  final AutomaticCalibrationService calibrationService;
  List<CameraDescription> available = [];
  final List<AutoscoreCamera> cameras = [];
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  final List<DartThrowResult> throws = [];
  FusedHit? pending;
  FusedHit? lastHit;
  String status = 'Drei Kameras auswählen und verbinden.';
  bool busy = false, running = false, disposed = false;
  bool automaticCounting = false;
  int _unresolvedSamples = 0;
  static const unresolvedThrow = DartThrowResult(
    label: 'Nicht erkannt',
    baseValue: 0,
    scoredPoints: 0,
    isDouble: false,
    isTriple: false,
  );
  int? automaticVisitDartLimit = 3;
  bool Function(DartThrowResult)? onAutomaticThrow;
  VoidCallback? onAutomaticVisitCleared;
  final _visitReset = AutomaticVisitReset();
  final _bounceDetector = AutomaticBounceDetector();
  static const bouncerThrow = DartThrowResult(
    label: 'Bouncer',
    baseValue: 0,
    scoredPoints: 0,
    isDouble: false,
    isTriple: false,
    isMiss: true,
  );
  bool get waitingForEmpty => _visitReset.waitingForEmpty;
  Timer? _timer;
  Future<void> _queue = Future.value();
  int _generation = 0;
  Future<void> _serial(Future<void> Function() action) {
    final next = _queue.then((_) => action());
    _queue = next.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return next;
  }

  void _notify() {
    if (!disposed) notifyListeners();
  }

  Future<void> discover() async {
    try {
      available = await platform.availableCameras();
      status = available.length < 3
          ? 'Es wurden ${available.length} Kameras gefunden. Drei USB-Kameras werden benötigt.'
          : 'Drei unterschiedliche Kameras auswählen.';
    } catch (_) {
      status =
          'Kameras können auf diesem Gerät nicht gelesen werden. Der Prototyp benötigt Windows.';
    }
    _notify();
  }

  Future<void> connect(List<int> indices) {
    final generation = ++_generation;
    busy = true;
    running = false;
    _timer?.cancel();
    _notify();
    return _serial(() async {
      await _release();
      try {
        if (indices.length != 3 ||
            indices.toSet().length != 3 ||
            indices.any((i) => i < 0 || i >= available.length)) {
          throw StateError('Bitte drei unterschiedliche Kameras auswählen.');
        }
        Map<String, BoardCalibration> saved = {};
        try {
          saved = await storage.load();
        } catch (_) {
          status = 'Gespeicherte Kalibrierung ungültig. Bitte neu kalibrieren.';
        }
        for (final index in indices) {
          if (disposed || generation != _generation) return;
          final description = available[index];
          final id = await platform.createCameraWithSettings(
            description,
            const MediaSettings(
              resolutionPreset: ResolutionPreset.high,
              enableAudio: false,
            ),
          );
          final init = Completer<CameraInitializedEvent>();
          final subscription = platform.onCameraInitialized(id).listen((event) {
            if (!init.isCompleted) init.complete(event);
          });
          _subscriptions.add(
            platform.onCameraError(id).listen((event) {
              if (!init.isCompleted) {
                init.completeError(StateError(event.description));
              } else {
                status =
                    'Kamerafehler: ${event.description}. Bitte neu verbinden.';
                unawaited(stop());
              }
            }),
          );
          _subscriptions.add(
            platform.onCameraClosing(id).listen((_) {
              status = 'Kamera getrennt. Bitte neu verbinden.';
              unawaited(stop());
            }),
          );
          // Register before initialization so every created camera gets released.
          final camera = AutoscoreCamera(
            description,
            id,
            4 / 3,
            deviceIndex: index,
          );
          cameras.add(camera);
          try {
            final eventFuture = init.future.timeout(
              const Duration(seconds: 15),
            );
            final results = await Future.wait<dynamic>([
              platform.initializeCamera(id),
              eventFuture,
            ]);
            final event = results[1] as CameraInitializedEvent;
            final ready = AutoscoreCamera(
              description,
              id,
              event.previewWidth > 0 && event.previewHeight > 0
                  ? event.previewWidth / event.previewHeight
                  : 4 / 3,
              deviceIndex: index,
            );
            ready.calibration = saved[ready.calibrationKey];
            cameras[cameras.length - 1] = ready;
          } finally {
            await subscription.cancel();
          }
        }
        if (disposed || generation != _generation) return;
        await _capture();
        await _autoCalibrate(generation);
        if (automaticCounting && cameras.every((c) => c.calibration != null)) {
          await _arm(generation);
        }
      } catch (e) {
        status =
            'Verbindung fehlgeschlagen: $e. Autodarts und andere Kamera-Apps schließen, falls sie die Kameras belegen.';
        await _release();
      } finally {
        if (disposed || generation != _generation) {
          await _release();
        }
        busy = false;
        _notify();
      }
    });
  }

  Future<List<GrayFrame>> _capture() async {
    final observations = <(AutoscoreCamera, Uint8List, Future<GrayFrame>)>[];
    // camera_windows names files by millisecond only, without a camera ID.
    // Read and remove each file before the next camera can reuse that name.
    for (final camera in cameras) {
      final file = await platform.takePicture(camera.id);
      late Uint8List bytes;
      try {
        bytes = await file.readAsBytes();
      } finally {
        try {
          await File(file.path).delete();
        } catch (_) {}
      }
      final decoding = compute(decodeCameraFrame, bytes);
      // Observe early failures while collecting the remaining camera files;
      // Future.wait below still propagates the error before publishing images.
      decoding.ignore();
      observations.add((camera, bytes, decoding));
    }
    final frames = await Future.wait(observations.map((entry) => entry.$3));
    for (var i = 0; i < observations.length; i++) {
      observations[i].$1.snapshot = observations[i].$2;
      observations[i].$1.snapshotAspectRatio =
          frames[i].sourceAspectRatio ?? frames[i].width / frames[i].height;
    }
    return frames;
  }

  Future<void> autoCalibrate() {
    final generation = _generation;
    if (running || pending != null || busy) return Future.value();
    busy = true;
    _notify();
    return _serial(() async {
      try {
        if (disposed || generation != _generation || cameras.length != 3) {
          return;
        }
        await _capture();
        await _autoCalibrate(generation);
        if (automaticCounting && cameras.every((c) => c.calibration != null)) {
          await _arm(generation);
        }
      } catch (e) {
        status = 'Automatische Kalibrierung fehlgeschlagen: $e';
      } finally {
        busy = false;
        _notify();
      }
    });
  }

  Future<void> _autoCalibrate(int generation) async {
    if (disposed || generation != _generation) return;
    lastHit = null;
    for (final camera in cameras) {
      camera.calibration = null;
      camera.candidateCalibration = null;
      camera.diagnostics = null;
      camera.detectedAxis = null;
      camera.lastAcceptedAxis = null;
      camera.changedPixels = const [];
      camera.changeFraction = 0;
      camera.calibrationMessage = 'Warte auf automatische Erkennung …';
    }
    final results = <AutomaticCalibrationResult?>[];
    for (var i = 0; i < cameras.length; i++) {
      if (disposed || generation != _generation) return;
      final camera = cameras[i];
      status = 'Kamera ${i + 1}: Ringe, Bull und Zahlen automatisch erkennen …';
      camera.calibrationMessage = 'Automatische Kalibrierung läuft …';
      _notify();
      try {
        final result = await calibrationService.calibrate(camera.snapshot!);
        camera.diagnostics = result.diagnostics;
        camera.candidateCalibration = result.calibration;
        results.add(result);
        camera.calibrationMessage = result.numberCount > 0
            ? '${result.numberCount} Zahlen erkannt · Board-Geometrie geprüft'
            : 'Zahlenring mit automatisch gelernter Referenz abgeglichen · Board-Geometrie geprüft';
      } catch (e) {
        if (e is CalibrationFailure) camera.diagnostics = e.diagnostics;
        results.add(null);
        camera.calibrationMessage = e.toString();
      }
    }
    if (disposed || generation != _generation) return;
    final referenceService = calibrationService;
    if (referenceService is ReferenceAutomaticCalibrationService) {
      final references = [
        for (var i = 0; i < results.length; i++)
          if (results[i] != null) i,
      ];
      for (var i = 0; i < results.length; i++) {
        if (results[i] != null) continue;
        for (final reference in references) {
          status =
              'Kamera ${i + 1}: Zahlenring mit Kamera ${reference + 1} abgleichen …';
          _notify();
          try {
            final result = await referenceService.calibrateUsingReference(
              cameras[i].snapshot!,
              cameras[reference].snapshot!,
              results[reference]!.calibration,
            );
            if (disposed || generation != _generation) return;
            results[i] = result;
            cameras[i].diagnostics = result.diagnostics;
            cameras[i].candidateCalibration = result.calibration;
            cameras[i].calibrationMessage =
                'Zahlenring mit Kamera ${reference + 1} abgeglichen · Board-Geometrie geprüft';
            break;
          } catch (_) {
            if (disposed || generation != _generation) return;
          }
        }
      }
    }
    if (results.length != 3 || results.any((r) => r == null)) {
      status =
          'Kalibrierung nicht vollständig. Hinweise an den Kameras prüfen, Board leeren und erneut automatisch kalibrieren.';
      return;
    }
    Map<String, BoardCalibration> saved;
    try {
      saved = await storage.load();
    } catch (_) {
      saved = {};
    }
    for (var i = 0; i < 3; i++) {
      saved[cameras[i].calibrationKey] = results[i]!.calibration;
    }
    try {
      await storage.save(saved);
      if (disposed || generation != _generation) return;
      for (var i = 0; i < 3; i++) {
        cameras[i].calibration = results[i]!.calibration;
      }
      status =
          'Alle drei Kameras automatisch kalibriert. Leeres Board als Referenz aufnehmen.';
    } catch (e) {
      status = 'Automatische Kalibrierung konnte nicht gespeichert werden: $e';
    }
  }

  Future<void> arm() => _serial(() => _arm(_generation));

  Future<void> _arm(int generation) async {
    if (disposed ||
        generation != _generation ||
        cameras.length != 3 ||
        cameras.any((c) => c.calibration == null)) {
      return;
    }
    busy = true;
    running = false;
    _timer?.cancel();
    _notify();
    try {
      final frames = await _capture();
      if (disposed || generation != _generation) return;
      for (var i = 0; i < 3; i++) {
        cameras[i].reference = frames[i];
        cameras[i].emptyReference = frames[i];
        cameras[i].previous = frames[i];
        cameras[i].stable = 0;
        cameras[i].detectedAxis = null;
        cameras[i].lastAcceptedAxis = null;
        cameras[i].changedPixels = const [];
      }
      throws.clear();
      _visitReset.reset();
      _bounceDetector.reset();
      _unresolvedSamples = 0;
      pending = null;
      lastHit = null;
      running = true;
      status = automaticCounting
          ? 'Automatisches Zählen aktiv. Einen Dart werfen.'
          : 'Erkennung aktiv. Einen Dart werfen und auf den Treffervorschlag warten.';
      _schedule(_generation);
    } catch (e) {
      status = 'Referenzaufnahme fehlgeschlagen: $e';
    } finally {
      busy = false;
      _notify();
    }
  }

  void _schedule(int generation) {
    _timer?.cancel();
    _timer = Timer(
      const Duration(milliseconds: 80),
      () => unawaited(
        _serial(() async {
          if (disposed || !running || generation != _generation) return;
          try {
            final frames = await _capture();
            if (disposed || !running || generation != _generation) return;
            processFrames(frames);
          } catch (e) {
            running = false;
            status = 'Bildaufnahme fehlgeschlagen: $e. Bitte neu verbinden.';
          }
          _notify();
          if (running) _schedule(generation);
        }),
      ),
    );
  }

  /// Process one complete three-camera capture; separated for replay tests.
  @visibleForTesting
  void processFrames(List<GrayFrame> frames) {
    if (!running || frames.length != 3 || cameras.length != 3) return;
    const detector = FrameDetector();
    var stableViews = 0;
    for (var i = 0; i < 3; i++) {
      final c = cameras[i];
      c.changeFraction = detector.changedFraction(c.previous!, frames[i]);
      c.stable = c.changeFraction < .002 ? c.stable + 1 : 0;
      c.previous = frames[i];
      c.detectedAxis = detector.axis(c.reference!, frames[i], c.calibration!);
      c.changedPixels = detector.changeSamples(
        c.reference!,
        frames[i],
        c.calibration!,
      );
      if (c.stable >= 2) stableViews++;
    }
    if (automaticCounting && throws.isNotEmpty) {
      final state = _visitReset.observe(
        empty: cameras.map((c) => c.emptyReference!).toList(),
        occupied: cameras.map((c) => c.reference!).toList(),
        current: frames,
        stable: stableViews == 3,
        darts: throws.length,
        dartLimit: automaticVisitDartLimit,
      );
      if (state == VisitResetState.cleared) {
        for (var i = 0; i < 3; i++) {
          cameras[i].reference = frames[i];
          cameras[i].emptyReference = frames[i];
          cameras[i].stable = 0;
          cameras[i].lastAcceptedAxis = null;
          cameras[i].lastReference = null;
          cameras[i].detectedAxis = null;
          cameras[i].changedPixels = const [];
          cameras[i].changeFraction = 0;
        }
        throws.clear();
        pending = null;
        _unresolvedSamples = 0;
        _bounceDetector.reset();
        _visitReset.reset();
        lastHit = null;
        status = 'Board leer erkannt. Nächste Aufnahme bereit.';
        onAutomaticVisitCleared?.call();
        _notify();
        return;
      }
      if (state == VisitResetState.waitingForEmpty) {
        _bounceDetector.reset();
        _unresolvedSamples = 0;
        pending = null;
        lastHit = null;
        for (final camera in cameras) {
          camera.detectedAxis = null;
          camera.lastAcceptedAxis = null;
          camera.changedPixels = const [];
        }
        status =
            'Pfeile herausziehen. Das leere Board wird automatisch erkannt.';
        return;
      }
    }
    if (automaticCounting &&
        _bounceDetector.observe(
          reference: cameras.map((c) => c.reference!).toList(),
          current: frames,
          axes: cameras
              .map((c) => c.detectedAxis)
              .whereType<DartAxis>()
              .toList(),
          stable: stableViews >= 2,
          nowMilliseconds: DateTime.now().millisecondsSinceEpoch,
        )) {
      recordMissedThrow(bouncerThrow);
      status = 'Bouncer erkannt · 0 Punkte. Nächsten Dart werfen.';
      if (onAutomaticThrow?.call(bouncerThrow) == false) {
        running = false;
        _timer?.cancel();
      }
      return;
    }
    if (stableViews < 2) {
      _unresolvedSamples = 0;
      return;
    }
    final axes = <DartAxis>[];
    for (var i = 0; i < 3; i++) {
      final c = cameras[i];
      if (c.stable < 2) continue;
      final axis = c.detectedAxis;
      c.detectedAxis = axis;
      if (axis != null) axes.add(axis);
    }
    pending = fuseAxes(axes);
    if (pending == null &&
        automaticCounting &&
        cameras
                .where(
                  (c) =>
                      c.stable >= 2 &&
                      c.changedPixels.length >= 4 &&
                      detector.changedFraction(c.reference!, c.previous!) < .06,
                )
                .length >=
            2) {
      _unresolvedSamples++;
      if (_unresolvedSamples >= 3) {
        pending = decideAxes(axes);
        if (pending == null) {
          recordMissedThrow(unresolvedThrow);
          status =
              'Pfeil erkannt, Feld nicht bestimmbar. Bitte korrigieren; nächster Pfeil ist bereit.';
          if (onAutomaticThrow?.call(unresolvedThrow) == false) {
            running = false;
            _timer?.cancel();
          }
          return;
        }
      }
    }
    final hit = pending;
    if (hit == null) {
      status = cameras.every((camera) => camera.changedPixels.isEmpty)
          ? 'Bereit. Nächsten Dart werfen.'
          : axes.length < 2
          ? 'Neuer Pfeil noch nicht eindeutig sichtbar: ${axes.length} brauchbare Kameraachsen.'
          : 'Kameraachsen widersprechen sich. Bitte Diagnose über „Nicht erkannten Pfeil melden“ sichern.';
      return;
    }
    if (automaticCounting) {
      final result = BoardGeometry.score(hit.point);
      accept(result);
      if (onAutomaticThrow?.call(result) == false) {
        running = false;
        _timer?.cancel();
        status = 'Automatisches Zählen angehalten.';
      } else if (hit.needsReview && throws.length < 3) {
        status = '${result.label} automatisch gezählt · Treffer unsicher.';
      }
    } else {
      running = false;
      status = hit.needsReview
          ? 'Treffer unsicher oder nahe am Draht. Bitte prüfen.'
          : 'Treffer erkannt. Prüfen und übernehmen.';
    }
  }

  void accept(DartThrowResult result) {
    if (pending == null) return;
    lastHit = pending;
    _bounceDetector.reset();
    _unresolvedSamples = 0;
    throws.add(result);
    pending = null;
    for (final c in cameras) {
      c.lastAcceptedAxis = c.detectedAxis;
      c.lastReference = c.reference;
      c.reference = c.previous;
      c.stable = 0;
    }
    if (automaticCounting || throws.length < 3) {
      running = true;
      status =
          automaticCounting &&
              automaticVisitDartLimit != null &&
              throws.length >= automaticVisitDartLimit!
          ? 'Drei Pfeile gezählt. Herausziehen; nächste Aufnahme startet automatisch.'
          : 'Treffer übernommen. Nächsten Dart werfen.';
      _schedule(_generation);
    } else {
      status =
          'Aufnahme beendet. Darts entfernen und leeres Board neu aufnehmen.';
    }
    _notify();
  }

  bool recordMissedThrow(DartThrowResult result) {
    if (!automaticCounting ||
        !running ||
        waitingForEmpty ||
        cameras.length != 3 ||
        cameras.any((c) => c.previous == null)) {
      return false;
    }
    throws.add(result);
    _unresolvedSamples = 0;
    _bounceDetector.reset();
    pending = null;
    lastHit = null;
    for (final camera in cameras) {
      camera.lastReference = camera.reference;
      camera.reference = camera.previous;
      camera.lastAcceptedAxis = null;
      camera.stable = 0;
    }
    status = 'Übersehener Pfeil nachgetragen. Nächsten Dart werfen.';
    _notify();
    return true;
  }

  Future<void> stop() {
    ++_generation;
    _timer?.cancel();
    running = false;
    pending = null;
    _notify();
    return _serial(_release);
  }

  Future<void> _release() async {
    running = false;
    _timer?.cancel();
    for (final s in _subscriptions) {
      await s.cancel();
    }
    _subscriptions.clear();
    for (final c in cameras) {
      try {
        await platform.dispose(c.id);
      } catch (_) {}
    }
    cameras.clear();
  }

  @override
  void dispose() {
    disposed = true;
    ++_generation;
    running = false;
    _timer?.cancel();
    unawaited(_serial(_release));
    super.dispose();
  }
}
