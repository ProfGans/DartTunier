import 'dart:math';
import 'dart:io';
import 'package:file_selector/file_selector.dart';
import '../../application/capture_autoscore_evidence.dart';
import '../../application/scorer_diagnostics.dart';
import 'package:flutter/material.dart';
import '../../application/autoscoring_controller.dart';
import '../../application/camera_selection.dart';
import '../../domain/board_geometry.dart';
import '../../domain/flat_board_projection.dart';
import '../../../scorer/domain/x01/x01_models.dart';
import '../../../scorer/domain/scorer_hit.dart';
import '../autoscoring_page.dart';
import 'flat_board_view.dart';
import '../../data/autoscore_setup_store.dart';
import '../../domain/autoscore_setup.dart';
import 'scorer_recognition_quality.dart';
import 'general_diagnostic_button.dart';
import 'dart_position_dialog.dart';
import '../../application/autoscore_lifecycle_policy.dart';

/// A compact review surface. Camera setup stays off the scoring workspace.
class ScorerCameraPanel extends StatefulWidget {
  const ScorerCameraPanel({
    super.key,
    required this.onAccept,
    required this.onClose,
    required this.dartsLeft,
    this.enabled = true,
    this.controller,
    this.onPreview,
    this.attempts = const [],
    this.onLocations,
    this.setupStore,
    this.activity,
    this.isInputEnabled,
    this.dartsLeftProvider,
  });
  final void Function(List<DartThrowResult>) onAccept;
  final VoidCallback onClose;
  final bool Function(List<DartThrowResult>, List<bool?>)? onPreview;
  final List<bool> attempts;
  final ValueChanged<List<DartLocation?>>? onLocations;
  final AutoscoreSetupStore? setupStore;
  final Listenable? activity;
  final bool Function()? isInputEnabled;
  final int Function()? dartsLeftProvider;
  final int dartsLeft;
  final bool enabled;
  final AutoscoringController? controller;
  @override
  State<ScorerCameraPanel> createState() => _ScorerCameraPanelState();
}

class _ScorerCameraPanelState extends State<ScorerCameraPanel>
    with WidgetsBindingObserver {
  late final camera = widget.controller ?? AutoscoringController();
  final darts = <DartThrowResult>[];
  final points = <BoardPoint>[];
  final estimated = <bool>[];
  final overrides = <bool?>[];
  final locations = <DartLocation?>[];
  late final setupStore = widget.setupStore ?? AutoscoreSetupStore.instance;
  final setupThrows = <AutoscoreSetupThrow?>[];
  final quality = <FusedHit?>[];
  final diagnostics = ScorerDiagnostics();
  bool submitted = false;
  int _limit = 3;
  bool configuring = false;
  bool _lifecycleAllowsRecognition = true;
  bool _resumeAfterBackground = false;
  bool _placingMissing = false;
  bool _resumeAfterActivity = false;
  bool get _inputEnabled => widget.isInputEnabled?.call() ?? widget.enabled;
  int get _dartsLeft => widget.dartsLeftProvider?.call() ?? widget.dartsLeft;

  void _activityChanged() {
    if (!mounted || configuring || _placingMissing) return;
    if (!_inputEnabled) {
      _resumeAfterActivity =
          _resumeAfterActivity || camera.running || _resumeAfterBackground;
      camera.pauseRecognition();
    } else if (_resumeAfterActivity && _lifecycleAllowsRecognition) {
      if (darts.isEmpty) {
        _limit = _dartsLeft;
        camera.automaticVisitDartLimit = _limit;
      }
      if (camera.resumeRecognition()) _resumeAfterActivity = false;
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    camera.addListener(_changed);
    widget.activity?.addListener(_activityChanged);
    diagnostics.addListener(_changed);
    _bind();
    _connect();
  }

  void _bind() {
    camera.reuseSavedCalibration = true;
    camera.automaticCounting = true;
    _limit = _dartsLeft;
    camera.automaticVisitDartLimit = _limit;
    camera.onAutomaticThrow = (dart) {
      if (!mounted ||
          !_inputEnabled ||
          _placingMissing ||
          submitted ||
          darts.length >= _limit) {
        return false;
      }
      setState(() {
        darts.add(dart);
        setupThrows.add(
          setupStore.record(
            estimated: camera.lastHit?.needsReview ?? false,
            bounce: dart.label == 'Bouncer',
            detectedLabel: dart.label,
          ),
        );
        final hit = camera.lastHit;
        quality.add(hit);
        final evidence = captureAutoscoreEvidence(camera);
        evidence?.hit.addAll({
          'setupId': setupThrows.last?.setupId,
          'setupName': setupStore.active.name,
        });
        diagnostics.record(dart.label, evidence);
        locations.add(
          hit == null
              ? null
              : DartLocation(
                  hit.point.x,
                  hit.point.y,
                  estimated: hit.needsReview,
                ),
        );
        overrides.add(null);
        estimated.add(camera.lastHit?.needsReview ?? false);
        points.add(camera.lastHit?.point ?? const Point(0, 220));
      });
      widget.onLocations?.call(List.of(locations));
      final ended =
          widget.onPreview?.call(List.of(darts), List.of(overrides)) ??
          darts.length >= _limit;
      if (ended) camera.automaticVisitDartLimit = darts.length;
      return true; // Continue polling until removal confirms the visit.
    };
    // Keep the recorded visit available for correction until it is submitted.
    camera.onAutomaticVisitCleared = () {
      if (!mounted) return;
      for (final token in setupThrows) {
        setupStore.review(token, corrected: false);
      }
      widget.onAccept(List.of(darts));
      setState(() {
        darts.clear();
        setupThrows.clear();
        locations.clear();
        quality.clear();
        diagnostics.nextVisit();
        points.clear();
        estimated.clear();
        overrides.clear();
      });
      _limit = _dartsLeft;
      camera.automaticVisitDartLimit = _limit;
      _activityChanged();
    };
  }

  void _preview() {
    widget.onLocations?.call(List.of(locations));
    final ended =
        widget.onPreview?.call(List.of(darts), List.of(overrides)) ??
        darts.length >= _limit;
    camera.automaticVisitDartLimit = ended ? darts.length : _limit;
  }

  @override
  void didUpdateWidget(covariant ScorerCameraPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activity != widget.activity) {
      oldWidget.activity?.removeListener(_activityChanged);
      widget.activity?.addListener(_activityChanged);
    }
    _activityChanged();
  }

  Future<void> _connect() async {
    await setupStore.load();
    if (!mounted) return;
    await camera.discover();
    if (!mounted || camera.available.length < 3) return;
    final selected = preferredAutoscoreCameras(
      camera.available,
      preferred: setupStore.active.cameraKeys,
    );
    setupStore.saveSettings(
      cameras: [
        for (final i in selected) autoscoreCameraKey(camera.available, i),
      ],
    );
    await camera.connect(selected);
    if (mounted) {
      _activityChanged();
      if (!_lifecycleAllowsRecognition) camera.pauseRecognition();
    }
  }

  void _changed() {
    _activityChanged();
    if (!_lifecycleAllowsRecognition && camera.running) {
      _resumeAfterBackground = true;
    }
    if (!configuring &&
        (!_inputEnabled || !_lifecycleAllowsRecognition || _placingMissing)) {
      camera.pauseRecognition();
    }
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (configuring) return;
    if (pauseAutoscoreForLifecycle(state)) {
      if (_lifecycleAllowsRecognition) _resumeAfterBackground = camera.running;
      _lifecycleAllowsRecognition = false;
      camera.pauseRecognition();
    } else {
      _lifecycleAllowsRecognition = true;
      if (_resumeAfterBackground && _inputEnabled && !_placingMissing) {
        camera.resumeRecognition();
      }
      _resumeAfterBackground = false;
    }
    if (state == AppLifecycleState.detached) {
      _resumeAfterBackground = false;
      _resumeAfterActivity = false;
    }
    _activityChanged();
    if (mounted) setState(() {});
  }

  Future<void> _setup() async {
    if (configuring) return;
    configuring = true;
    camera.pauseRecognition();
    if (!mounted) return;
    final route = MaterialPageRoute<void>(
      builder: (_) => AutoscoringPage(
        controller: camera,
        title: 'Autoscoring einrichten',
        setupStore: setupStore,
      ),
    );
    await Navigator.of(context).push(route);
    // The setup page clears its callbacks on disposal. Rebind only after its
    // reverse transition and disposal have finished.
    await route.completed;
    if (!mounted) return;
    camera.pauseRecognition();
    _bind();
    configuring = false;
    setState(() {
      darts.clear();
      setupThrows.clear();
      locations.clear();
      quality.clear();
      diagnostics.nextVisit();
      overrides.clear();
      estimated.clear();
      points.clear();
      submitted = false;
    });
    // Keep the accepted calibration and live devices. No reconnect or automatic
    // calibration when leaving setup. Test darts require explicit empty-board
    // confirmation using the existing start button.
    if (_inputEnabled &&
        _lifecycleAllowsRecognition &&
        camera.throws.isEmpty &&
        camera.pending == null) {
      camera.resumeRecognition();
    }
  }

  Future<void> _next() async {
    await camera.arm();
    if (!mounted || !camera.running) return;
    for (final token in setupThrows) {
      setupStore.review(token, corrected: false);
    }
    setState(() {
      darts.clear();
      setupThrows.clear();
      locations.clear();
      quality.clear();
      diagnostics.nextVisit();
      overrides.clear();
      estimated.clear();
      points.clear();
      submitted = false;
    });
    _limit = _dartsLeft;
    camera.automaticVisitDartLimit = _limit;
  }

  Future<void> _recalibrate() async {
    if (camera.busy || darts.isNotEmpty || configuring) return;
    camera.pauseRecognition();
    await camera.autoCalibrate();
    if (mounted) setState(() {});
  }

  Future<void> _missingDart() async {
    if (_placingMissing ||
        camera.busy ||
        !_inputEnabled ||
        darts.length >= min(_limit, camera.automaticVisitDartLimit ?? _limit)) {
      return;
    }
    _placingMissing = true;
    final wasRunning = camera.running;
    camera.pauseRecognition();
    final evidence = captureAutoscoreEvidence(
      camera,
      missed: true,
      allowPartial: true,
    );
    try {
      final index = await showDialog<int>(
        context: context,
        builder: (context) => SimpleDialog(
          title: const Text('Welcher Dart fehlt?'),
          children: [
            for (var i = 0; i <= darts.length; i++)
              SimpleDialogOption(
                onPressed: () => Navigator.pop(context, i),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'Dart ${i + 1}${i < darts.length ? ' · vor ${darts[i].label} einfügen' : ' · nachtragen'}',
                  ),
                ),
              ),
          ],
        ),
      );
      if (!mounted || index == null) return;
      final point = await showDialog<BoardPoint>(
        context: context,
        builder: (_) => DartPositionDialog(
          cameras: [
            for (final c in camera.cameras)
              if (c.snapshot != null && c.calibration != null)
                FlatBoardCamera(c.snapshot!, c.calibration!),
          ],
        ),
      );
      if (!mounted || point == null) return;
      final result = BoardGeometry.score(point);
      camera.recordManualThrow(result);
      // Preserve actual throw order in the scorer and in the camera visit.
      final recorded = camera.throws.removeLast();
      camera.throws.insert(index, recorded);
      setState(() {
        darts.insert(index, result);
        points.insert(index, point);
        locations.insert(
          index,
          DartLocation(point.x, point.y, corrected: true),
        );
        quality.insert(index, null);
        estimated.insert(index, false);
        overrides.insert(index, null);
        final token = setupStore.record(
          estimated: true,
          bounce: false,
          missing: true,
          detectedLabel: 'Nicht erkannt',
        );
        setupThrows.insert(index, token);
        setupStore.review(token, corrected: true);
        setupStore.verify(
          token,
          correct: false,
          missing: true,
          actualLabel: result.label,
        );
        diagnostics.insertMissing(index, evidence);
      });
      _preview();
      await diagnostics.correct(index, result.label, point);
    } finally {
      _placingMissing = false;
      if (mounted &&
          wasRunning &&
          _inputEnabled &&
          _lifecycleAllowsRecognition) {
        camera.resumeRecognition();
      }
      if (mounted) setState(() {});
    }
  }

  Future<void> _exportDiagnostic() async {
    final path = diagnostics.path;
    if (path == null) return;
    try {
      final location = await getSaveLocation(
        suggestedName: 'autoscore_korrektur.zip',
        acceptedTypeGroups: [
          const XTypeGroup(label: 'Diagnose-ZIP', extensions: ['zip']),
        ],
      );
      if (location == null) return;
      if (File(path).absolute.path != File(location.path).absolute.path) {
        await File(path).copy(location.path);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Diagnose-ZIP gespeichert.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Diagnose-Export fehlgeschlagen. Bitte erneut versuchen.',
            ),
          ),
        );
      }
    }
  }

  void _removeDart(int index) {
    if (!_inputEnabled || submitted || _placingMissing || configuring) return;
    diagnostics.remove(
      index,
      points[index],
      captureAutoscoreEvidence(camera, allowPartial: true),
    );
    setupStore.review(setupThrows[index], corrected: true);
    setupStore.verify(
      setupThrows[index],
      correct: false,
      extra: true,
      actualLabel: 'Kein echter Wurf',
    );
    setState(() {
      darts.removeAt(index);
      points.removeAt(index);
      locations.removeAt(index);
      quality.removeAt(index);
      estimated.removeAt(index);
      overrides.removeAt(index);
      setupThrows.removeAt(index);
    });
    camera.removeManualThrow(index);
    _preview();
  }

  Future<void> _confirmRemoval() async {
    await camera.confirmDartsRemoved(beforeReset: () {});
    if (mounted && darts.isNotEmpty) {
      // Explicit removal confirmation must also work without a camera stream.
      camera.confirmManualRemovalWithoutCapture();
    }
  }

  @override
  void dispose() {
    diagnostics.removeListener(_changed);
    diagnostics.dispose();
    WidgetsBinding.instance.removeObserver(this);
    camera.removeListener(_changed);
    widget.activity?.removeListener(_activityChanged);
    camera.onAutomaticThrow = null;
    camera.onAutomaticVisitCleared = null;
    if (widget.controller == null) camera.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!_inputEnabled)
            const Text(
              'Autoscoring pausiert · wartet auf die nächste Aufnahme.',
            ),
          Row(
            children: [
              const Expanded(child: Text('Autoscoring')),
              IconButton(
                tooltip: 'Kameras einrichten',
                onPressed: darts.isEmpty ? _setup : null,
                icon: const Icon(Icons.settings_outlined),
              ),
              IconButton(
                tooltip: 'Autoscoring schließen',
                onPressed: widget.onClose,
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: FlatBoardView(
                cameras: [
                  for (final c in camera.cameras)
                    if (c.snapshot != null && c.calibration != null)
                      FlatBoardCamera(c.snapshot!, c.calibration!),
                ],
                markers: [
                  for (var i = 0; i < darts.length; i++)
                    FlatBoardMarker(
                      i,
                      points[i],
                      '${darts[i].label}${estimated[i] ? ' · Schätzung' : ''}',
                    ),
                ],
                onMoved: (i, point) {
                  if (!submitted) {
                    setupStore.review(setupThrows[i], corrected: true);
                    setupStore.verify(
                      setupThrows[i],
                      correct: false,
                      actualLabel: BoardGeometry.score(point).label,
                    );
                    setState(() {
                      points[i] = point;
                      locations[i] = DartLocation(
                        point.x,
                        point.y,
                        corrected: true,
                      );
                      darts[i] = BoardGeometry.score(point);
                      estimated[i] = false;
                      diagnostics.correct(i, darts[i].label, point);
                      _preview();
                    });
                  }
                },
              ),
            ),
          ),
          if (camera.busy) const LinearProgressIndicator(),
          if (darts.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (var i = 0; i < darts.length; i++)
                  OutlinedButton.icon(
                    onPressed: _inputEnabled && !submitted && !_placingMissing
                        ? () => _removeDart(i)
                        : null,
                    icon: const Icon(Icons.delete_outline),
                    label: Text('Dart ${i + 1} (${darts[i].label}) entfernen'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(48, 48),
                    ),
                  ),
              ],
            ),
          if (_inputEnabled &&
              darts.length <
                  min(_limit, camera.automaticVisitDartLimit ?? _limit))
            OutlinedButton.icon(
              onPressed: camera.busy || _placingMissing ? null : _missingDart,
              icon: const Icon(Icons.add_location_alt_outlined),
              label: const Text('Nicht erkannten Dart nachtragen'),
            ),
          if (camera.cameras.length == 3) ...[
            if (camera.reusedCalibration)
              const Text('Gespeicherte Kalibrierung aktiv.'),
            OutlinedButton.icon(
              onPressed:
                  camera.busy ||
                      darts.isNotEmpty ||
                      !_inputEnabled ||
                      configuring
                  ? null
                  : _recalibrate,
              icon: const Icon(Icons.center_focus_strong),
              label: const Text('Board leer · Neu kalibrieren'),
            ),
            const Text(
              'Kamera oder Board verschoben? Dann neu kalibrieren. Die Werte werden automatisch gespeichert.',
            ),
          ],
          if (darts.isNotEmpty && _inputEnabled)
            OutlinedButton(
              onPressed: camera.busy ? null : _confirmRemoval,
              child: const Text('Pfeile gezogen · Aufnahme bestätigen'),
            ),
          GeneralDiagnosticButton(
            controller: camera,
            setupId: widget.setupStore?.active.id,
          ),
          if (diagnostics.saving)
            const Text('Korrekturdiagnose wird gespeichert …'),
          if (diagnostics.error != null) Text(diagnostics.error!),
          if (diagnostics.path != null)
            OutlinedButton.icon(
              onPressed: _exportDiagnostic,
              icon: const Icon(Icons.save_alt),
              label: const Text('Letzte Korrektur: Diagnose-ZIP speichern'),
            ),
          ScorerRecognitionQuality(
            hits: quality,
            corrected: [
              for (final location in locations) location?.corrected ?? false,
            ],
          ),
          if (camera.cameras.length < 3 || (!camera.running && _inputEnabled))
            Text(camera.status),
          if (!camera.running && _inputEnabled && darts.isNotEmpty)
            OutlinedButton(
              onPressed: camera.busy
                  ? null
                  : () {
                      camera.resumeRecognition();
                      setState(() {});
                    },
              child: const Text('Erkennung mit vorhandenen Darts fortsetzen'),
            ),
          const Text(
            'Jeder Dart zählt live. Pfeile herausziehen bestätigt die Aufnahme.',
          ),
          for (var i = 0; i < min(widget.attempts.length, darts.length); i++)
            FilterChip(
              label: Text('Dart ${i + 1}: Doppelversuch'),
              tooltip:
                  'Aus dem Restscore abgeleitet. Bei anderem Ziel bitte korrigieren.',
              selected: widget.attempts[i],
              onSelected: (value) {
                setState(() => overrides[i] = value);
                _preview();
              },
            ),
          if (!camera.running && _inputEnabled && darts.isEmpty)
            OutlinedButton(
              onPressed: camera.busy ? null : _next,
              child: const Text('Board leer · Erkennung starten'),
            ),
        ],
      ),
    ),
  );
}
