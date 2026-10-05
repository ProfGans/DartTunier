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
import '../domain/multi_camera_consensus.dart';
import '../domain/temporal_hit_decision.dart';
import '../domain/uncertain_hit_recovery.dart';
import '../domain/detail_hit_refinement.dart';
import '../domain/forced_hit_decision.dart';
import '../data/windows_video_source.dart';
import 'decode_video_frames.dart';
import '../domain/dart_tip_detection.dart';
import '../domain/spatial_board_contact.dart';
import '../../scorer/domain/x01/x01_models.dart';
import 'recognition_diagnostic_trace.dart';
import 'package:package_info_plus/package_info_plus.dart';

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
  Map<String, Object?> calibrationQuality = const {};
  DartAxis? detectedAxis, lastAcceptedAxis;
  List<DartAxis> axisCandidates = const [], lastAxisCandidates = const [];
  final List<GrayFrame> recentFrames = [];
  List<GrayFrame> lastDetectionFrames = const [];
  List<GrayFrame> postDetectionFrames = [];
  List<BoardPoint> changedPixels = const [];
  double changeFraction = 0;
  GrayFrame? reference, previous, emptyReference;
  GrayFrame? lastReference;
  Uint8List? snapshot;
  double? snapshotAspectRatio;
  int stable = 0;
  String? calibrationMessage;
}

/// Windows consumes buffered preview video; other platforms use snapshots.
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
  final _video = WindowsVideoSource();
  final _videoSilence = Stopwatch();
  bool get continuousVideo => _video.active;
  Map<String, Object?> get videoMetrics => {
    'continuousVideo': continuousVideo,
    'timestampBasis': 'hostArrivalMonotonic',
    'skewMicroseconds': _video.synchronizer?.lastSkewUs,
    'discardedForSynchronization': _video.synchronizer?.discarded ?? 0,
    'nativeDroppedFrames': _video.nativeDropped,
  };
  final CameraPlatform platform;
  final AutoscoringStorage storage;
  bool reuseSavedCalibration = false;
  bool reusedCalibration = false;
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
  int _boundaryWaitSamples = 0;
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
  final _hitDecision = TemporalHitDecision();
  final _uncertainRecovery = UncertainHitRecovery();
  Map<String, Object?> get recoveryMetrics => _uncertainRecovery.metrics;
  final _decisionAxisSamples = <List<DartAxis?>>[];
  final _decisionCaptureTimes = <List<int?>>[];
  final _diagnosticTrace = RecognitionDiagnosticTrace();
  List<Map<String, Object?>> get diagnosticTimeline =>
      _diagnosticTrace.snapshot();
  String decisionReason = 'notEvaluated', tipDecisionReason = 'notEvaluated';
  String? lastCaptureError, lastCaptureErrorStack;
  Map<String, Object?> diagnosticEnvironment = {
    'algorithmRevision': 'diagnostics-v8-2026-10-05',
    'operatingSystem': Platform.operatingSystem,
    'operatingSystemVersion': Platform.operatingSystemVersion,
    'dartVersion': Platform.version,
    'buildMode': kReleaseMode
        ? 'release'
        : kProfileMode
        ? 'profile'
        : 'debug',
  };
  int decisionSelectedFrame = -1;
  List<Map<String, Object>> decisionMetrics = const [];
  bool alternativesUsed = false;
  bool detailRefined = false;
  bool tipContactConfirmed = false;
  List<DartTipObservation?> tipObservations = const [];
  SpatialBoardContact? spatialContact;
  final _acceptedBoardPoints = <BoardPoint>[];
  int _robinFrames = 0;
  static const robinHoodThrow = DartThrowResult(
    label: 'Robin Hood',
    baseValue: 0,
    scoredPoints: 0,
    isDouble: false,
    isTriple: false,
    isMiss: true,
  );
  double captureMilliseconds = 0;
  Stopwatch? _processingWatch;
  double get processingMilliseconds =>
      (_processingWatch?.elapsedMicroseconds ?? 0) / 1000;
  Duration get captureDelay => Duration(
    milliseconds:
        pending != null ||
            _unresolvedSamples > 0 ||
            cameras.any(
              (c) => c.detectedAxis != null && c.changedPixels.length >= 4,
            )
        ? 20
        : 80,
  );
  static const bouncerThrow = DartThrowResult(
    label: 'Bouncer',
    baseValue: 0,
    scoredPoints: 0,
    isDouble: false,
    isTriple: false,
    isMiss: true,
  );
  bool get waitingForEmpty => _visitReset.waitingForEmpty;
  List<Map<String, Object>> get removalMetrics => _visitReset.cameraMetrics
      .map((metrics) => Map<String, Object>.of(metrics))
      .toList();
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

  String _qualityNote(Map<String, Object?> quality) {
    final count = quality['observations'];
    final error =
        quality[quality['applied'] == true
            ? 'validationRmsAfterMillimetres'
            : 'validationRmsBeforeMillimetres'];
    if (count is! num || error is! num) return '';
    return '\nRingprüfung: $count Punkte · ${error.toStringAsFixed(1)} mm Abweichung';
  }

  Future<void> discover() async {
    try {
      available = await platform.availableCameras();
      status = available.length < 3
          ? 'Es wurden ${available.length} Kameras gefunden. Drei USB-Kameras werden benötigt.'
          : 'Drei unterschiedliche Kameras auswählen.';
    } catch (_) {
      status =
          'Kameras können auf diesem Gerät nicht gelesen werden. Unter Linux FFmpeg und v4l2-ctl installieren und Kamerazugriff prüfen.';
    }
    _notify();
  }

  Future<void> _loadDiagnosticPackageInfo() async {
    try {
      final package = await PackageInfo.fromPlatform();
      diagnosticEnvironment.addAll({
        'appVersion': package.version,
        'appBuild': package.buildNumber,
      });
    } catch (_) {
      diagnosticEnvironment['appVersion'] = null;
      diagnosticEnvironment['appBuild'] = null;
    }
  }

  Future<void> connect(List<int> indices) {
    unawaited(_loadDiagnosticPackageInfo());
    _diagnosticTrace.clear();
    lastCaptureError = lastCaptureErrorStack = null;
    reusedCalibration = false;
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
        if (Platform.isWindows) {
          await _video.configure(cameras.map((c) => c.id).toList());
        }
        await _capture();
        if (reuseSavedCalibration &&
            cameras.every((c) => c.calibration != null)) {
          reusedCalibration = true;
          for (final c in cameras) {
            c.calibrationMessage = 'Gespeicherte Kalibrierung übernommen.';
          }
        } else {
          await _autoCalibrate(generation);
        }
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
    final watch = Stopwatch()..start();
    if (_video.active) {
      while (watch.elapsedMilliseconds < 2500) {
        final batches = await _video.read();
        if (batches.isNotEmpty) {
          _videoSilence
            ..reset()
            ..start();
          final frames = await compute(decodeVideoFrames, batches.last);
          _publishVideoSnapshots(frames);
          captureMilliseconds = watch.elapsedMicroseconds / 1000;
          return frames;
        }
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      throw StateError(
        'Kein zeitlich passendes Bild von allen drei Kameras. USB-Verbindung prüfen.',
      );
    }
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
    captureMilliseconds = watch.elapsedMicroseconds / 1000;
    return frames;
  }

  void _publishVideoSnapshots(List<GrayFrame> frames) {
    for (var i = 0; i < 3; i++) {
      cameras[i].snapshot = frames[i].colorImage;
      cameras[i].snapshotAspectRatio = frames[i].sourceAspectRatio;
    }
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
    reusedCalibration = false;
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
        camera.calibrationQuality = result.quality;
        camera.candidateCalibration = result.calibration;
        results.add(result);
        camera.calibrationMessage = result.numberCount > 0
            ? '${result.numberCount} Zahlen erkannt · Board-Geometrie geprüft'
            : 'Zahlenring mit automatisch gelernter Referenz abgeglichen · Board-Geometrie geprüft';
        camera.calibrationMessage =
            '${camera.calibrationMessage}${_qualityNote(result.quality)}';
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
            cameras[i].calibrationQuality = result.quality;
            cameras[i].candidateCalibration = result.calibration;
            cameras[i].calibrationMessage =
                'Zahlenring mit Kamera ${reference + 1} abgeglichen · Board-Geometrie geprüft';
            cameras[i].calibrationMessage =
                '${cameras[i].calibrationMessage}${_qualityNote(result.quality)}';
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

  /// Capture the user's now-empty board before replacing the old references.
  Future<void> confirmDartsRemoved({required VoidCallback beforeReset}) =>
      _serial(() => _arm(_generation, beforeReset: beforeReset));

  Future<void> _arm(int generation, {VoidCallback? beforeReset}) async {
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
      beforeReset?.call();
      for (var i = 0; i < 3; i++) {
        cameras[i].reference = frames[i];
        cameras[i].emptyReference = frames[i];
        cameras[i].previous = frames[i];
        cameras[i].stable = 0;
        cameras[i].detectedAxis = null;
        cameras[i].lastAcceptedAxis = null;
        cameras[i].lastReference = null;
        cameras[i].recentFrames.clear();
        cameras[i].axisCandidates = const [];
        cameras[i].lastAxisCandidates = const [];
        cameras[i].lastDetectionFrames = const [];
        cameras[i].changedPixels = const [];
        cameras[i].changeFraction = 0;
      }
      throws.clear();
      _acceptedBoardPoints.clear();
      _robinFrames = 0;
      _visitReset.reset();
      _bounceDetector.reset();
      _hitDecision.reset();
      _uncertainRecovery.reset();
      _decisionAxisSamples.clear();
      _decisionCaptureTimes.clear();
      _unresolvedSamples = 0;
      _boundaryWaitSamples = 0;
      pending = null;
      lastHit = null;
      decisionMetrics = const [];
      decisionSelectedFrame = -1;
      detailRefined = false;
      alternativesUsed = false;
      if (beforeReset != null) onAutomaticVisitCleared?.call();
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
      continuousVideo ? const Duration(milliseconds: 10) : captureDelay,
      () => unawaited(
        _serial(() async {
          if (disposed || !running || generation != _generation) return;
          try {
            if (continuousVideo) {
              final batches = await _video.read();
              if (batches.isEmpty && _videoSilence.elapsedMilliseconds > 2500) {
                throw StateError(
                  'Drei zeitlich passende Videobilder fehlen. USB-Verbindungen prüfen.',
                );
              }
              if (batches.isNotEmpty) {
                _videoSilence
                  ..reset()
                  ..start();
              }
              for (final batch in batches) {
                final watch = Stopwatch()..start();
                final frames = await compute(decodeVideoFrames, batch);
                if (disposed || !running || generation != _generation) return;
                captureMilliseconds = watch.elapsedMicroseconds / 1000;
                _publishVideoSnapshots(frames);
                processFrames(frames);
              }
            } else {
              final frames = await _capture();
              if (disposed || !running || generation != _generation) return;
              processFrames(frames);
            }
          } catch (e, stack) {
            lastCaptureError = e.toString();
            lastCaptureErrorStack = stack.toString();
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
    _processingWatch = Stopwatch()..start();
    _diagnosticTrace.begin(frames, throws.length);
    try {
      _processFrames(frames);
    } finally {
      _diagnosticTrace.checkpoint('remaining', {
        'status': status,
        'running': running,
        'waitingForEmpty': waitingForEmpty,
        'throwsAfter': throws.length,
      });
      _processingWatch!.stop();
    }
  }

  void _processFrames(List<GrayFrame> frames) {
    if (!running || frames.length != 3 || cameras.length != 3) return;
    const detector = FrameDetector();
    var stableViews = 0;
    for (var i = 0; i < 3; i++) {
      final c = cameras[i];
      if (c.lastReference != null && c.postDetectionFrames.length < 4) {
        final f = frames[i];
        c.postDetectionFrames.add(
          GrayFrame(
            f.width,
            f.height,
            f.pixels,
            colorImage: f.colorImage,
            timestampUs: f.timestampUs,
            sequence: f.sequence,
          ),
        );
      }
      c.changeFraction = detector.changedFraction(c.previous!, frames[i]);
      c.stable = c.changeFraction < .002 ? c.stable + 1 : 0;
      c.previous = frames[i];
      c.axisCandidates = const [];
      c.recentFrames.add(frames[i]);
      if (c.recentFrames.length > (continuousVideo ? 8 : 3)) {
        c.recentFrames.removeAt(0);
      }
      c.detectedAxis = detector.axis(c.reference!, frames[i], c.calibration!);
      c.changedPixels = detector.changeSamples(
        c.reference!,
        frames[i],
        c.calibration!,
      );
      if (c.stable >= 2) stableViews++;
    }
    _diagnosticTrace.checkpoint('motionAndAxes', {
      'cameras': [
        for (final c in cameras)
          {
            'stableSamples': c.stable,
            'changedFraction': c.changeFraction,
            'changedPixels': c.changedPixels.length,
            'axis': c.detectedAxis == null
                ? null
                : {
                    'a': c.detectedAxis!.a,
                    'b': c.detectedAxis!.b,
                    'c': c.detectedAxis!.c,
                    'confidence': c.detectedAxis!.confidence,
                  },
          },
      ],
    });
    if (automaticCounting && throws.isNotEmpty) {
      final state = _visitReset.observe(
        empty: cameras.map((c) => c.emptyReference!).toList(),
        occupied: cameras.map((c) => c.reference!).toList(),
        current: frames,
        stable: stableViews == 3,
        darts: throws.length,
        dartLimit: automaticVisitDartLimit,
        calibrations: cameras.map((c) => c.calibration!).toList(),
      );
      _diagnosticTrace.checkpoint('removal', {
        'state': state.name,
        'cameraMetrics': removalMetrics,
      });
      if (state == VisitResetState.cleared) {
        for (var i = 0; i < 3; i++) {
          cameras[i].reference = frames[i];
          cameras[i].emptyReference = frames[i];
          cameras[i].stable = 0;
          cameras[i].lastAcceptedAxis = null;
          cameras[i].lastReference = null;
          cameras[i].recentFrames.clear();
          cameras[i].axisCandidates = const [];
          cameras[i].lastAxisCandidates = const [];
          cameras[i].lastDetectionFrames = const [];
          cameras[i].detectedAxis = null;
          cameras[i].changedPixels = const [];
          cameras[i].changeFraction = 0;
        }
        throws.clear();
        _acceptedBoardPoints.clear();
        _robinFrames = 0;
        pending = null;
        _unresolvedSamples = 0;
        _boundaryWaitSamples = 0;
        _bounceDetector.reset();
        _hitDecision.reset();
        _uncertainRecovery.reset();
        _decisionAxisSamples.clear();
        _decisionCaptureTimes.clear();
        _visitReset.reset();
        lastHit = null;
        decisionMetrics = const [];
        decisionSelectedFrame = -1;
        detailRefined = false;
        alternativesUsed = false;
        status = 'Board leer erkannt. Nächste Aufnahme bereit.';
        onAutomaticVisitCleared?.call();
        _notify();
        return;
      }
      if (state == VisitResetState.waitingForEmpty) {
        _bounceDetector.reset();
        _hitDecision.reset();
        _uncertainRecovery.reset();
        _decisionAxisSamples.clear();
        _decisionCaptureTimes.clear();
        _unresolvedSamples = 0;
        _boundaryWaitSamples = 0;
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
          nowMilliseconds: frames.first.timestampUs == null
              ? DateTime.now().millisecondsSinceEpoch
              : frames
                        .map((f) => f.timestampUs!)
                        .reduce((a, b) => a > b ? a : b) ~/
                    1000,
        )) {
      recordMissedThrow(bouncerThrow);
      status = 'Bouncer erkannt · 0 Punkte. Nächsten Dart werfen.';
      if (onAutomaticThrow?.call(bouncerThrow) == false) {
        running = false;
        _timer?.cancel();
      }
      return;
    }
    _diagnosticTrace.checkpoint('bounce');
    final localizedViews = cameras
        .where(
          (c) =>
              c.changedPixels.length >= 4 &&
              detector.changedFraction(c.reference!, c.previous!) < .06,
        )
        .length;
    if (automaticCounting &&
        localizedViews >= 2 &&
        (stableViews >= 1 || _unresolvedSamples > 0)) {
      _unresolvedSamples++;
    } else if (localizedViews < 2) {
      _unresolvedSamples = 0;
      if (cameras.every(
        (camera) => camera.changedPixels.isEmpty && camera.detectedAxis == null,
      )) {
        _hitDecision.reset();
        _uncertainRecovery.reset();
        _decisionAxisSamples.clear();
        _decisionCaptureTimes.clear();
      }
    }
    final deadlineReached = automaticCounting && _unresolvedSamples >= 6;
    if (stableViews < 2 && !deadlineReached) {
      return;
    }
    final axes = <DartAxis>[];
    for (var i = 0; i < 3; i++) {
      final c = cameras[i];
      if (c.stable < 2 && !deadlineReached) continue;
      final axis = c.detectedAxis;
      c.detectedAxis = axis;
      if (axis != null) axes.add(axis);
    }
    alternativesUsed = false;
    pending = fuseAxes(axes);
    if (pending == null || pending!.needsReview) {
      for (final camera in cameras) {
        camera.axisCandidates = camera.stable < 2
            ? const []
            : detector.candidates(
                camera.reference!,
                camera.previous!,
                camera.calibration!,
                primary: camera.detectedAxis,
              );
      }
      final consensus = chooseCameraConsensus(
        cameras.map((c) => c.axisCandidates).toList(),
      );
      if (consensus.hit != null) {
        pending = consensus.hit;
        alternativesUsed =
            consensus.alternativesUsed ||
            List.generate(
              3,
              (i) => consensus.axes[i] != cameras[i].detectedAxis,
            ).any((v) => v);
        if (alternativesUsed) {
          pending = FusedHit(
            pending!.point,
            pending!.residual,
            pending!.views,
            forcedDecision: true,
          );
        }
        for (var i = 0; i < 3; i++) {
          cameras[i].detectedAxis = consensus.axes[i];
        }
      }
    }
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
      if (_unresolvedSamples >= 3) {
        pending = forceHitDecision(
          axes,
          cameras
              .map(
                (camera) => camera.changedPixels
                    .map((p) => camera.calibration!.project(p))
                    .toList(),
              )
              .toList(),
        );
      }
    }
    if (deadlineReached && pending == null) {
      pending = forceHitDecision(
        axes,
        cameras
            .map(
              (camera) => camera.changedPixels
                  .map((p) => camera.calibration!.project(p))
                  .toList(),
            )
            .toList(),
      );
    }
    _diagnosticTrace.checkpoint('fusion', {
      'localizedViews': localizedViews,
      'stableViews': stableViews,
      'unresolvedSamples': _unresolvedSamples,
      'deadlineReached': deadlineReached,
      'alternativesUsed': alternativesUsed,
    });
    var recoveredContactConfirmed = false;
    if (continuousVideo &&
        pending != null &&
        cameras.every((c) => c.emptyReference != null)) {
      final recovered = _uncertainRecovery.observe(
        pending!,
        cameras.map((c) => c.reference!).toList(),
        cameras.map((c) => c.emptyReference!).toList(),
        frames,
        cameras.map((c) => c.calibration!).toList(),
        cameras.map((c) => c.axisCandidates).toList(),
      );
      if (recovered != null) {
        recoveredContactConfirmed = true;
        pending = recovered.hit;
        alternativesUsed = true;
        for (var i = 0; i < 3; i++) {
          cameras[i].detectedAxis = recovered.axes[i];
        }
      }
    }
    _diagnosticTrace.checkpoint('contactRecovery', {
      'confirmed': recoveredContactConfirmed,
    });
    detailRefined = false;
    var temporalSupportViews = 0;
    if (pending != null) {
      final refined = refineHitDetail(
        pending!,
        cameras.map((c) => c.reference!).toList(),
        frames,
        cameras.map((c) => c.calibration!).toList(),
        cameras.map((c) => c.stable < 2 ? null : c.detectedAxis).toList(),
      );
      pending = refined.hit;
      detailRefined = refined.applied;
      for (var i = 0; i < 3; i++) {
        cameras[i].detectedAxis = refined.axes[i];
      }
      _diagnosticTrace.checkpoint('detailRefinement', {
        'applied': detailRefined,
      });
      temporalSupportViews =
          recoveredContactConfirmed ||
              (pending!.views == 3 &&
                  pending!.residual <= 3 &&
                  refined.axes
                          .whereType<DartAxis>()
                          .where((a) => a.confidence >= .8)
                          .length ==
                      3)
          ? 3
          : pending!.views.clamp(0, 2);
      final tip = refineTipContact(
        pending!,
        cameras.map((c) => c.reference!).toList(),
        frames,
        cameras.map((c) => c.calibration!).toList(),
        refined.axes,
      );
      tipContactConfirmed = tip.confirmed;
      tipDecisionReason = tip.reason;
      tipObservations = tip.observations;
      if (continuousVideo) pending = tip.hit;
      _diagnosticTrace.checkpoint('tipRefinement', {
        'reason': tip.reason,
        'confirmed': tip.confirmed,
        'appliedToRecognition': continuousVideo,
      });
      spatialContact = locateSpatialContact(
        [
          for (var i = 0; i < 3; i++)
            estimateBoardPose(
              cameras[i].calibration!,
              aspectRatio:
                  frames[i].sourceAspectRatio ??
                  frames[i].width / frames[i].height,
            ),
        ],
        [
          for (var i = 0; i < 3; i++)
            tip.observations[i] == null
                ? null
                : DartTipObservation(
                    cameras[i].calibration!.lens.undistort(
                      tip.observations[i]!.image,
                    ),
                    tip.observations[i]!.board,
                    tip.observations[i]!.confidence,
                  ),
        ],
        _acceptedBoardPoints,
      );
      _robinFrames = continuousVideo && spatialContact?.robinHood == true
          ? _robinFrames + 1
          : 0;
    }
    _diagnosticTrace.checkpoint('spatialAndBoundary');
    final hit = pending;
    if (hit == null) {
      _boundaryWaitSamples = 0;
      status = cameras.every((camera) => camera.changedPixels.isEmpty)
          ? 'Bereit. Nächsten Dart werfen.'
          : axes.length < 2
          ? 'Neuer Pfeil noch nicht eindeutig sichtbar: ${axes.length} brauchbare Kameraachsen.'
          : 'Kameraachsen widersprechen sich. Bitte Diagnose über „Nicht erkannten Pfeil melden“ sichern.';
      return;
    }
    // Two-camera decisions can flip even away from a wire when the third
    // already sees a shaft but has not settled yet.
    // Give its already visible axis a bounded chance to join the consensus.
    if (automaticCounting &&
        !deadlineReached &&
        hit.views == 2 &&
        cameras.any(
          (camera) => camera.stable < 2 && camera.detectedAxis != null,
        )) {
      if (++_boundaryWaitSamples < 3) {
        status = 'Dritte Kamera kurz abgleichen …';
        return;
      }
    } else {
      _boundaryWaitSamples = 0;
    }
    if (automaticCounting) {
      _decisionAxisSamples.add(cameras.map((c) => c.detectedAxis).toList());
      _decisionCaptureTimes.add(frames.map((f) => f.timestampUs).toList());
      final observed = _hitDecision.observe(
        hit,
        supportingViews: temporalSupportViews,
      );
      final decision =
          observed ??
          (deadlineReached
              ? FusedHit(
                  hit.point,
                  hit.residual,
                  hit.views,
                  forcedDecision: true,
                )
              : null);
      decisionReason = observed == null && deadlineReached
          ? 'deadlineCurrentEstimate'
          : _hitDecision.reason;
      _diagnosticTrace.checkpoint('temporalSelection', {
        'reason': decisionReason,
        'selectedIndex': _hitDecision.selectedIndex,
      });
      decisionMetrics = [
        for (var i = 0; i < _hitDecision.metrics.length; i++)
          {
            ..._hitDecision.metrics[i],
            'captureTimestampsMicroseconds': _decisionCaptureTimes[i],
            'axes': [
              for (final a in _decisionAxisSamples[i])
                a == null
                    ? null
                    : {
                        'a': a.a,
                        'b': a.b,
                        'c': a.c,
                        'confidence': a.confidence,
                      },
            ],
          },
      ];
      if (decision == null) {
        status = 'Treffer kurz über mehrere Bilder abgleichen …';
        return;
      }
      pending = decision;
      decisionSelectedFrame = observed == null
          ? _decisionAxisSamples.length - 1
          : _hitDecision.selectedIndex;
      for (var i = 0; i < 3; i++) {
        cameras[i].detectedAxis =
            _decisionAxisSamples[decisionSelectedFrame][i];
      }
      final result = _robinFrames >= 2
          ? robinHoodThrow
          : BoardGeometry.score(decision.point);
      _acceptedBoardPoints.add(decision.point);
      accept(result);
      if (onAutomaticThrow?.call(result) == false) {
        running = false;
        _timer?.cancel();
        status = 'Automatisches Zählen angehalten.';
      } else if (decision.needsReview && throws.length < 3) {
        status =
            '${result.label} automatisch gezählt · Schätzung, bitte prüfen.';
      }
    } else {
      running = false;
      status = hit.needsReview
          ? 'Schätzung: ${BoardGeometry.score(hit.point).label}. Bitte prüfen.'
          : 'Treffer erkannt. Prüfen und übernehmen.';
    }
  }

  void accept(DartThrowResult result) {
    if (pending == null) return;
    lastHit = pending;
    _bounceDetector.reset();
    _hitDecision.reset();
    _uncertainRecovery.reset();
    _decisionAxisSamples.clear();
    _decisionCaptureTimes.clear();
    _unresolvedSamples = 0;
    _boundaryWaitSamples = 0;
    throws.add(result);
    _diagnosticTrace.checkpoint('accepted', {
      'score': result.label,
      'reason': decisionReason,
      'throwsAfter': throws.length,
    });
    pending = null;
    for (final c in cameras) {
      c.lastAcceptedAxis = c.detectedAxis;
      c.lastAxisCandidates = List.of(c.axisCandidates);
      c.lastDetectionFrames = List.of(c.recentFrames);
      c.postDetectionFrames = [];
      c.recentFrames.clear();
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
    recordManualThrow(result);
    return true;
  }

  /// Explicit user correction is independent of recognition readiness.
  void recordManualThrow(DartThrowResult result) {
    if (disposed) return;
    throws.add(result);
    _unresolvedSamples = 0;
    _boundaryWaitSamples = 0;
    _bounceDetector.reset();
    _hitDecision.reset();
    _uncertainRecovery.reset();
    _decisionAxisSamples.clear();
    _decisionCaptureTimes.clear();
    pending = null;
    lastHit = null;
    decisionMetrics = const [];
    decisionSelectedFrame = -1;
    detailRefined = false;
    for (final camera in cameras) {
      camera.lastAxisCandidates = List.of(camera.axisCandidates);
      camera.lastDetectionFrames = List.of(camera.recentFrames);
      camera.recentFrames.clear();
      camera.lastReference = camera.reference;
      if (camera.previous != null) camera.reference = camera.previous;
      camera.lastAcceptedAxis = identical(result, unresolvedThrow)
          ? camera.detectedAxis
          : null;
      camera.stable = 0;
    }
    status = 'Übersehener Pfeil nachgetragen. Nächsten Dart werfen.';
    _notify();
  }

  /// Delete a false detection while retaining the current visual baseline.
  void removeManualThrow(int index) {
    if (disposed || index < 0 || index >= throws.length) return;
    throws.removeAt(index);
    _acceptedBoardPoints.clear();
    _robinFrames = 0;
    _visitReset.reset();
    _hitDecision.reset();
    _uncertainRecovery.reset();
    _bounceDetector.reset();
    _decisionAxisSamples.clear();
    _decisionCaptureTimes.clear();
    _unresolvedSamples = 0;
    _boundaryWaitSamples = 0;
    pending = null;
    lastHit = null;
    status = 'Erkennung entfernt. Nächsten Dart werfen.';
    _notify();
  }

  /// Confirm removal without frames; require fresh references before resuming.
  void confirmManualRemovalWithoutCapture() {
    pauseRecognition();
    throws.clear();
    _acceptedBoardPoints.clear();
    _robinFrames = 0;
    pending = null;
    lastHit = null;
    _visitReset.reset();
    _bounceDetector.reset();
    _hitDecision.reset();
    _uncertainRecovery.reset();
    _decisionAxisSamples.clear();
    _decisionCaptureTimes.clear();
    for (final c in cameras) {
      c.reference = null;
      c.emptyReference = null;
      c.previous = null;
    }
    status =
        'Aufnahme manuell bestätigt. Für automatische Erkennung das leere Board neu aufnehmen.';
    onAutomaticVisitCleared?.call();
    _notify();
  }

  /// Pause polling without discarding calibration, references or pending darts.
  void pauseRecognition() {
    running = false;
    _timer?.cancel();
  }

  /// Resume the same board state. Never take a new empty-board reference here:
  /// darts may still be on the board after a focus change or bot turn.
  bool resumeRecognition() {
    if (disposed ||
        busy ||
        cameras.length != 3 ||
        cameras.any(
          (c) =>
              c.calibration == null ||
              c.reference == null ||
              c.emptyReference == null,
        )) {
      return false;
    }
    running = true;
    _videoSilence
      ..reset()
      ..start();
    _schedule(_generation);
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
    await _video.close();
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
