import 'dart:math';
import 'package:flutter/material.dart';
import '../../application/autoscoring_controller.dart';
import '../../application/camera_selection.dart';
import '../../domain/board_geometry.dart';
import '../../domain/flat_board_projection.dart';
import '../../../scorer/domain/x01/x01_models.dart';
import '../../../scorer/domain/scorer_hit.dart';
import '../autoscoring_page.dart';
import 'flat_board_view.dart';

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
  });
  final void Function(List<DartThrowResult>) onAccept;
  final VoidCallback onClose;
  final bool Function(List<DartThrowResult>, List<bool?>)? onPreview;
  final List<bool> attempts;
  final ValueChanged<List<DartLocation?>>? onLocations;
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
  bool submitted = false;
  int _limit = 3;
  bool configuring = false;
  bool _foreground = true;
  bool _resumeOnFocus = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    camera.addListener(_changed);
    _bind();
    _connect();
  }

  void _bind() {
    camera.automaticCounting = true;
    _limit = widget.dartsLeft;
    camera.automaticVisitDartLimit = _limit;
    camera.onAutomaticThrow = (dart) {
      if (!mounted || !widget.enabled || submitted || darts.length >= _limit) {
        return false;
      }
      setState(() {
        darts.add(dart);
        final hit = camera.lastHit;
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
      widget.onAccept(List.of(darts));
      setState(() {
        darts.clear();
        locations.clear();
        points.clear();
        estimated.clear();
        overrides.clear();
      });
      _limit = 3;
      camera.automaticVisitDartLimit = 3;
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
    if (!widget.enabled) {
      // Bot turns are driven solely by the scorer's timer. Keep the cameras
      // connected but do not run recognition while a bot is throwing.
      camera.pauseRecognition();
    } else if (!oldWidget.enabled &&
        _foreground &&
        camera.cameras.length == 3) {
      if (darts.isEmpty) camera.automaticVisitDartLimit = widget.dartsLeft;
      camera.resumeRecognition();
    }
  }

  Future<void> _connect() async {
    await camera.discover();
    if (!mounted || camera.available.length < 3) return;
    await camera.connect(preferredAutoscoreCameras(camera.available));
    if (mounted && (!widget.enabled || !_foreground)) camera.pauseRecognition();
  }

  void _changed() {
    if (!_foreground && camera.running) _resumeOnFocus = true;
    if (!configuring && (!widget.enabled || !_foreground)) {
      camera.pauseRecognition();
    }
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (configuring) return;
    if (state != AppLifecycleState.resumed) {
      if (_foreground) _resumeOnFocus = camera.running;
      _foreground = false;
      camera.pauseRecognition();
    } else {
      _foreground = true;
      if (_resumeOnFocus && widget.enabled) camera.resumeRecognition();
      _resumeOnFocus = false;
    }
    if (mounted) setState(() {});
  }

  Future<void> _setup() async {
    if (configuring) return;
    configuring = true;
    await camera.stop();
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AutoscoringPage(
          controller: camera,
          title: 'Autoscoring einrichten',
        ),
      ),
    );
    if (!mounted) return;
    await camera.stop();
    _bind();
    configuring = false;
    setState(() {
      darts.clear();
      locations.clear();
      overrides.clear();
      estimated.clear();
      points.clear();
      submitted = false;
    });
    await _connect();
  }

  Future<void> _next() async {
    await camera.arm();
    if (!mounted || !camera.running) return;
    setState(() {
      darts.clear();
      locations.clear();
      overrides.clear();
      estimated.clear();
      points.clear();
      submitted = false;
    });
    _limit = widget.dartsLeft;
    camera.automaticVisitDartLimit = _limit;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    camera.removeListener(_changed);
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
          if (!widget.enabled)
            const Text('Autoscoring pausiert · Bots werfen selbstständig.'),
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
                    setState(() {
                      points[i] = point;
                      locations[i] = DartLocation(
                        point.x,
                        point.y,
                        corrected: true,
                      );
                      darts[i] = BoardGeometry.score(point);
                      estimated[i] = false;
                      widget.onLocations?.call(List.of(locations));
                      widget.onPreview?.call(
                        List.of(darts),
                        List.of(overrides),
                      );
                    });
                  }
                },
              ),
            ),
          ),
          if (camera.busy) const LinearProgressIndicator(),
          if (camera.cameras.length < 3 || (!camera.running && widget.enabled))
            Text(camera.status),
          if (!camera.running && widget.enabled && darts.isNotEmpty)
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
          for (var i = 0; i < widget.attempts.length; i++)
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
          if (!camera.running && widget.enabled && darts.isEmpty)
            OutlinedButton(
              onPressed: camera.busy ? null : _next,
              child: const Text('Board leer · Erkennung starten'),
            ),
        ],
      ),
    ),
  );
}
