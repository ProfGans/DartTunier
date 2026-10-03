import 'dart:math';
import 'package:flutter/material.dart';
import '../../application/autoscoring_controller.dart';
import '../../application/camera_selection.dart';
import '../../domain/board_geometry.dart';
import '../../domain/flat_board_projection.dart';
import '../../../scorer/domain/x01/x01_models.dart';
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
  });
  final void Function(List<DartThrowResult>) onAccept;
  final VoidCallback onClose;
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
  bool submitted = false;
  bool configuring = false;

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
    camera.automaticVisitDartLimit = widget.dartsLeft;
    camera.onAutomaticThrow = (dart) {
      if (!mounted ||
          !widget.enabled ||
          submitted ||
          darts.length >= widget.dartsLeft) {
        return false;
      }
      setState(() {
        darts.add(dart);
        estimated.add(camera.lastHit?.needsReview ?? false);
        points.add(camera.lastHit?.point ?? const Point(0, 220));
      });
      return darts.length < widget.dartsLeft;
    };
    // Keep the recorded visit available for correction until it is submitted.
    camera.onAutomaticVisitCleared = () {};
  }

  @override
  void didUpdateWidget(covariant ScorerCameraPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled) {
      // Bot turns are driven solely by the scorer's timer. Keep the cameras
      // connected but do not run recognition while a bot is throwing.
      camera.running = false;
    }
  }

  Future<void> _connect() async {
    await camera.discover();
    if (!mounted || camera.available.length < 3) return;
    await camera.connect(preferredAutoscoreCameras(camera.available));
    if (mounted && !widget.enabled) camera.running = false;
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) camera.stop();
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
      estimated.clear();
      points.clear();
      submitted = false;
    });
    camera.automaticVisitDartLimit = widget.dartsLeft;
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
                onPressed: _setup,
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
                      darts[i] = BoardGeometry.score(point);
                      estimated[i] = false;
                    });
                  }
                },
              ),
            ),
          ),
          if (camera.busy) const LinearProgressIndicator(),
          if (camera.cameras.length < 3) Text(camera.status),
          const Text(
            'Treffer bei Bedarf verschieben, dann Aufnahme übernehmen.',
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton(
                onPressed: !widget.enabled || submitted || darts.isEmpty
                    ? null
                    : () {
                        camera.running = false;
                        setState(() => submitted = true);
                        widget.onAccept(List.of(darts));
                      },
                child: const Text('Aufnahme übernehmen'),
              ),
              OutlinedButton(
                onPressed:
                    !widget.enabled ||
                        camera.busy ||
                        (!submitted && darts.isNotEmpty)
                    ? null
                    : _next,
                child: const Text('Board leer · nächste Aufnahme'),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
