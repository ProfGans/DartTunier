import 'package:flutter/material.dart';
import 'dart:io';
import 'package:file_selector/file_selector.dart';
import '../application/capture_autoscore_evidence.dart';
import '../data/autoscore_diagnostic_export.dart';
import '../../../shared/widgets/adaptive_content.dart';
import '../../scorer/domain/x01/x01_models.dart';
import '../application/autoscoring_controller.dart';
import '../application/camera_selection.dart';
import '../domain/board_geometry.dart';
import 'widgets/camera_recognition_view.dart';
import 'widgets/general_diagnostic_button.dart';
import 'widgets/dart_correction_dialog.dart';
import '../application/autoscore_audio_controller.dart';
import '../data/autoscore_audio_output.dart';
import 'widgets/autoscore_audio_controls.dart';
import '../data/autoscore_setup_store.dart';
import '../application/autoscore_lifecycle_policy.dart';

class AutoscoringPage extends StatefulWidget {
  const AutoscoringPage({
    super.key,
    this.controller,
    this.onThrow,
    this.onBoardCleared,
    this.matchStatus,
    this.title = 'Autoscorer · Prototyp',
    this.acceptLabel,
    this.summaryBuilder,
    this.automaticCounting = false,
    this.autoConnect = false,
    this.automaticVisitDartLimit = 3,
    this.audioThrows,
    this.setupStore,
    this.audioOutput,
  });
  final AutoscoringController? controller;

  /// Return false when a visit, leg or match ended, or input is unavailable.
  final bool Function(DartThrowResult)? onThrow;
  final VoidCallback? onBoardCleared;
  final String Function()? matchStatus;
  final String title;
  final String? acceptLabel;
  final WidgetBuilder? summaryBuilder;
  final bool automaticCounting;
  final bool autoConnect;
  final int? automaticVisitDartLimit;
  final List<DartThrowResult> Function()? audioThrows;
  final AutoscoreSetupStore? setupStore;
  final AutoscoreAudioOutput? audioOutput;
  @override
  State<AutoscoringPage> createState() => _AutoscoringPageState();
}

class _AutoscoringPageState extends State<AutoscoringPage>
    with WidgetsBindingObserver {
  late final c = widget.controller ?? AutoscoringController();
  late final audio = AutoscoreAudioController(
    setupStore: widget.setupStore,
    output: widget.audioOutput,
  );
  List<int> selected = [-1, -1, -1];
  bool visitEnded = false;
  bool _connectionAttempted = false;
  bool showRecognition = true, showColorSamples = false;
  bool _savingRemoval = false;
  String? _removalDiagnostic;

  Future<void> _confirmRemoval() async {
    setState(() => _savingRemoval = true);
    AutoscoreEvidence? evidence;
    try {
      await c.confirmDartsRemoved(
        beforeReset: () {
          evidence = captureAutoscoreEvidence(c, missed: true);
          evidence?.hit.addAll({
            'eventType': 'manualRemoval',
            'manualMissingReport': false,
            'statusBeforeReset': c.status,
            'waitingForEmpty': c.waitingForEmpty,
            'removalMetrics': c.removalMetrics,
            'throws': c.throws
                .map((d) => {'label': d.label, 'points': d.scoredPoints})
                .toList(),
          });
        },
      );
      if (evidence == null) {
        throw StateError(
          'Keine vollständige Kameraaufnahme verfügbar. ${c.status}',
        );
      }
      if (mounted) setState(() => visitEnded = false);
      final path = await const AutoscoreDiagnosticExport().save(
        evidence!,
        'Herausziehen nicht automatisch erkannt',
        'Board manuell leer bestätigt',
      );
      if (!mounted) return;
      setState(() => _removalDiagnostic = path);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Aufnahme zurückgesetzt. Diagnose gespeichert: $path'),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Herauszieh-Diagnose: $e')));
      }
    } finally {
      if (mounted) setState(() => _savingRemoval = false);
    }
  }

  Future<void> _exportRemoval() async {
    final path = _removalDiagnostic;
    if (path == null) return;
    try {
      final target = await getSaveLocation(
        suggestedName: 'autoscore_herausziehen.zip',
        acceptedTypeGroups: [
          const XTypeGroup(label: 'Diagnose-ZIP', extensions: ['zip']),
        ],
      );
      if (target != null &&
          File(path).absolute.path != File(target.path).absolute.path) {
        await File(path).copy(target.path);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Export fehlgeschlagen: $e')));
      }
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    c.addListener(_changed);
    c.automaticCounting = widget.automaticCounting;
    c.automaticVisitDartLimit = widget.automaticVisitDartLimit;
    c.onAutomaticVisitCleared = widget.automaticCounting
        ? () {
            audio.confirmRemoval();
            widget.onBoardCleared?.call();
          }
        : null;
    c.onAutomaticThrow = widget.automaticCounting
        ? (result) => widget.onThrow?.call(result) ?? true
        : null;
    selected = preferredAutoscoreCameras(
      c.available,
      preferred: widget.setupStore?.active.cameraKeys ?? const [],
    );
    _discover();
  }

  Future<void> _discover() async {
    final previous = List.of(c.available);
    final previousSelection = List.of(selected);
    await c.discover();
    if (!mounted) return;
    final defaults = preferredAutoscoreCameras(
      c.available,
      preferred: widget.setupStore?.active.cameraKeys ?? const [],
    );
    final retained = <int>{};
    final next = List<int>.filled(3, -1);
    for (var slot = 0; slot < 3; slot++) {
      final oldIndex = previousSelection[slot];
      if (oldIndex < 0 || oldIndex >= previous.length) continue;
      // Match the occurrence as well as the name for identical USB cameras.
      final name = previous[oldIndex].name;
      final occurrence = previous
          .take(oldIndex)
          .where((c) => c.name == name)
          .length;
      final matches = [
        for (var j = 0; j < c.available.length; j++)
          if (c.available[j].name == name) j,
      ];
      if (occurrence < matches.length && retained.add(matches[occurrence])) {
        next[slot] = matches[occurrence];
      }
    }
    for (var slot = 0; slot < 3; slot++) {
      if (next[slot] >= 0) continue;
      final candidates = [
        ...defaults,
        ...List.generate(c.available.length, (i) => i),
      ];
      next[slot] = candidates.firstWhere(
        (i) => i >= 0 && !retained.contains(i),
        orElse: () => -1,
      );
      if (next[slot] >= 0) retained.add(next[slot]);
    }
    setState(() => selected = next);
    if (widget.autoConnect &&
        !_connectionAttempted &&
        next.every((i) => i >= 0)) {
      _connectionAttempted = true;
      await c.connect(List.of(next));
    }
  }

  void _changed() {
    if (mounted) setState(() {});
    Future<void>.microtask(() {
      if (mounted) {
        audio.update(widget.audioThrows?.call() ?? List.of(c.throws));
        c.liveFrameTiming['audioEffect'] = audio.lastEffectTiming;
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (pauseAutoscoreForLifecycle(state)) {
      c.status =
          'Erkennung nach Hintergrundwechsel angehalten. Bitte neu verbinden.';
      c.stop();
    }
  }

  @override
  void dispose() {
    audio.dispose();
    WidgetsBinding.instance.removeObserver(this);
    c.removeListener(_changed);
    c.onAutomaticThrow = null;
    c.onAutomaticVisitCleared = null;
    if (widget.controller == null) c.dispose();
    super.dispose();
  }

  Future<void> _accept({bool correct = false}) async {
    final hit = c.pending;
    if (hit == null) return;
    var result = BoardGeometry.score(hit.point);
    if (correct) {
      final value = await showDialog<DartThrowResult>(
        context: context,
        builder: (_) => const DartCorrectionDialog(),
      );
      if (value == null || !mounted) return;
      result = value;
    }
    c.accept(result);
    if (widget.onThrow != null && !widget.onThrow!(result)) {
      c.running = false;
      c.status =
          'Spielzug beendet. Darts entfernen. Für den nächsten Spieler ein leeres Board aufnehmen.';
      setState(() => visitEnded = true);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.title)),
    body: AdaptiveContentList(
      children: [
        Text(
          'Drei Kameras · lokale Treffererkennung',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 12),
        const Text(
          'Windows-Prototyp: Kameras fest montieren, Board gleichmäßig beleuchten. Falls Kameras belegt sind, die Erkennung in Autodarts schließen. Kalibrierung und Bilder bleiben lokal.',
        ),
        const SizedBox(height: 16),
        if (widget.matchStatus != null)
          Text(
            widget.matchStatus!(),
            style: Theme.of(context).textTheme.titleLarge,
          ),
        AutoscoreAudioControls(controller: audio),
        if (widget.summaryBuilder != null) widget.summaryBuilder!(context),
        if (c.cameras.isEmpty) ...[
          for (var i = 0; i < 3; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: DropdownButtonFormField<int>(
                key: ValueKey('camera-$i-${c.available.length}-${selected[i]}'),
                initialValue:
                    selected[i] >= 0 && selected[i] < c.available.length
                    ? selected[i]
                    : null,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: 'Kamera ${i + 1}',
                  border: const OutlineInputBorder(),
                ),
                items: [
                  for (var j = 0; j < c.available.length; j++)
                    DropdownMenuItem(
                      value: j,
                      child: Text(
                        '${j + 1}: ${c.available[j].name}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: c.busy
                    ? null
                    : (value) => setState(() => selected[i] = value!),
              ),
            ),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              FilledButton.icon(
                onPressed: c.busy || c.available.length < 3
                    ? null
                    : () {
                        widget.setupStore?.saveSettings(
                          cameras: [
                            for (final index in selected)
                              if (index >= 0)
                                autoscoreCameraKey(c.available, index),
                          ],
                        );
                        c.connect(List.of(selected));
                      },
                icon: const Icon(Icons.videocam),
                label: Text(
                  widget.automaticCounting
                      ? 'Kameras verbinden · automatisch starten'
                      : 'Drei Kameras verbinden',
                ),
              ),
              OutlinedButton(
                onPressed: c.busy ? null : _discover,
                child: const Text('Kameras suchen'),
              ),
            ],
          ),
        ],
        if (c.busy)
          const Padding(
            padding: EdgeInsets.all(16),
            child: LinearProgressIndicator(),
          ),
        const SizedBox(height: 16),
        Text(c.status, style: Theme.of(context).textTheme.titleMedium),
        GeneralDiagnosticButton(
          controller: c,
          setupId: widget.setupStore?.active.id,
        ),
        if (c.continuousVideo)
          Text(
            'USB-Video · 3 Kameras · Zeitversatz ${((c.videoMetrics['skewMicroseconds'] as int? ?? 0) / 1000).toStringAsFixed(1)} ms',
          ),
        if (c.cameras.length == 3) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              OutlinedButton.icon(
                onPressed:
                    c.busy ||
                        _savingRemoval ||
                        c.cameras.any((camera) => camera.calibration == null)
                    ? null
                    : _confirmRemoval,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(48, 48),
                ),
                icon: const Icon(Icons.restart_alt),
                label: const Text('Pfeile herausgezogen · Reset + Diagnose'),
              ),
              if (_removalDiagnostic != null)
                OutlinedButton.icon(
                  onPressed: _exportRemoval,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(48, 48),
                  ),
                  icon: const Icon(Icons.save_alt),
                  label: const Text('Herauszieh-Diagnose speichern'),
                ),
            ],
          ),
          const Text(
            'Nur bei leerem Board drücken. Die Kamerabilder werden vor dem Reset gespeichert.',
          ),
        ],
        if (c.cameras.isNotEmpty) ...[
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Erkennung in Kamerabildern anzeigen'),
            value: showRecognition,
            onChanged: (value) => setState(() => showRecognition = value),
          ),
          if (showRecognition) ...[
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Erkannte Farbpixel zusätzlich anzeigen'),
              value: showColorSamples,
              onChanged: (value) =>
                  setState(() => showColorSamples = value ?? false),
            ),
            const RecognitionLegend(),
            const SizedBox(height: 12),
            const Text(
              'Orange zeigt auch verworfene Vorschläge. Pink markiert den zuletzt erkannten Treffer; ? bedeutet unsicher.',
            ),
          ],
        ],
        if (c.cameras.length == 3) ...[
          const SizedBox(height: 12),
          const Text(
            'Die Kalibrierung startet automatisch beim Verbinden. Dafür das Board leeren und den gesamten Double-Ring samt Zahlenring sichtbar halten.',
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: c.busy || c.running || c.pending != null
                  ? null
                  : c.autoCalibrate,
              icon: const Icon(Icons.auto_fix_high),
              label: const Text('Automatisch neu kalibrieren'),
            ),
          ),
        ],
        const SizedBox(height: 16),
        AdaptiveTileLayout(
          minTileWidth: 280,
          children: [
            for (var i = 0; i < c.cameras.length; i++)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Kamera ${i + 1}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(c.cameras[i].description.name),
                      const SizedBox(height: 8),
                      CameraRecognitionView(
                        key: ValueKey('camera-recognition-$i'),
                        camera: c.cameras[i],
                        hit: c.pending ?? c.lastHit,
                        showRecognition: showRecognition,
                        showColorSamples: showColorSamples,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        c.cameras[i].calibration == null
                            ? 'Noch nicht kalibriert'
                            : 'Automatisch kalibriert',
                      ),
                      if (c.cameras[i].calibrationMessage != null)
                        Text(c.cameras[i].calibrationMessage!),
                      if (showRecognition)
                        CameraRecognitionDetails(camera: c.cameras[i]),
                    ],
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        if (c.cameras.length == 3)
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              FilledButton.icon(
                onPressed:
                    visitEnded ||
                        c.busy ||
                        c.running ||
                        c.pending != null ||
                        c.cameras.any((camera) => camera.calibration == null)
                    ? null
                    : () {
                        c.arm();
                      },
                icon: const Icon(Icons.play_arrow),
                label: const Text('Board ist leer · Erkennung starten'),
              ),
              OutlinedButton(
                onPressed: c.busy
                    ? null
                    : () {
                        c.status = 'Erkennung gestoppt.';
                        c.stop();
                      },
                child: const Text('Kameras freigeben'),
              ),
            ],
          ),
        if (visitEnded)
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Zurück zum X01-Spiel · nächster Spieler'),
          ),
        if (c.pending != null)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${BoardGeometry.score(c.pending!.point).label} · ${BoardGeometry.score(c.pending!.point).scoredPoints} Punkte',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  Text(
                    '${c.pending!.views} Kameraansichten · Achsenabweichung ${c.pending!.residual.toStringAsFixed(1)} mm',
                  ),
                  if (c.pending!.needsReview)
                    const Text(
                      'Unsicherer Treffer: Drahtnähe oder abweichende Kameraansichten. Position am echten Board prüfen.',
                    ),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      FilledButton(
                        onPressed: () => _accept(),
                        child: Text(
                          widget.acceptLabel ??
                              (widget.onThrow == null
                                  ? 'Treffer bestätigen'
                                  : 'In X01 übernehmen'),
                        ),
                      ),
                      OutlinedButton(
                        onPressed: () => _accept(correct: true),
                        child: const Text('Treffer korrigieren'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        if (c.throws.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            'Aufnahme: ${c.throws.map((d) => d.label).join(' · ')} = ${c.throws.fold<int>(0, (s, d) => s + d.scoredPoints)} Punkte',
          ),
        ],
        const SizedBox(height: 16),
        const Text(
          'Grenzen: Bilddifferenz und geometrische Dartachsen, kein trainiertes KI-Modell. Verdeckte Darts, Schatten, Kamerabewegung und Linsenverzerrung können Treffer verhindern oder verfälschen. Abpraller / Fehlwürfe ohne sichtbaren Pfeil werden nicht erkannt.',
        ),
      ],
    ),
  );
}
