import 'package:flutter/material.dart';
import 'dart:io';
import 'package:file_selector/file_selector.dart';
import '../application/autoscore_demo_controller.dart';
import '../application/autoscoring_controller.dart';
import 'autoscoring_page.dart';
import '../../scorer/domain/x01/x01_models.dart';
import 'widgets/dart_correction_dialog.dart';
import '../application/capture_autoscore_evidence.dart';
import '../data/autoscore_diagnostic_export.dart';
import '../domain/board_geometry.dart';
import '../domain/lens_distortion.dart';
import '../domain/flat_board_projection.dart';
import 'widgets/flat_board_view.dart';
import 'widgets/dart_position_dialog.dart';

class AutoscoreDemoPage extends StatefulWidget {
  const AutoscoreDemoPage({super.key, this.controller, this.cameraController});
  final AutoscoreDemoController? controller;
  final AutoscoringController? cameraController;
  @override
  State<AutoscoreDemoPage> createState() => _AutoscoreDemoPageState();
}

class _AutoscoreDemoPageState extends State<AutoscoreDemoPage> {
  late final controller = widget.controller ?? AutoscoreDemoController();
  late final cameras = widget.cameraController ?? AutoscoringController();
  @override
  void initState() {
    super.initState();
    controller.addListener(_changed);
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  Future<void> _correct(int index) async {
    final result = await showDialog<DartThrowResult>(
      context: context,
      builder: (_) => const DartCorrectionDialog(),
    );
    if (!mounted || result == null) return;
    controller.review(index, result);
    await _saveDiagnostic(index);
  }

  Future<void> _setPosition(int index) async {
    final entry = controller.history[index];
    final point = await showDialog<BoardPoint>(
      context: context,
      builder: (_) => DartPositionDialog(
        cameras: entry.evidence == null
            ? _flatCameras(controller, cameras)
            : _evidenceCameras(entry.evidence!),
        initialPoint: entry.point,
      ),
    );
    if (!mounted || point == null) return;
    controller.movePoint(index, point);
    await _saveDiagnostic(index);
  }

  Future<void> _missed() async {
    final evidence = captureAutoscoreEvidence(cameras, missed: true);
    final visitLength = cameras.throws.length;
    final result = await showDialog<DartThrowResult>(
      context: context,
      builder: (_) => const DartCorrectionDialog(),
    );
    if (!mounted || result == null) return;
    if (cameras.throws.length != visitLength ||
        !cameras.recordMissedThrow(result)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Die Aufnahme hat sich geändert. Bitte erneut melden.'),
        ),
      );
      return;
    }
    const missed = DartThrowResult(
      label: 'Nicht erkannt',
      baseValue: 0,
      scoredPoints: 0,
      isDouble: false,
      isTriple: false,
    );
    controller.add(missed, evidence: evidence);
    final index = controller.history.length - 1;
    controller.review(index, result);
    await _saveDiagnostic(index);
  }

  Future<void> _saveDiagnostic(int index) async {
    final entry = controller.history[index];
    if (entry.evidence == null) return;
    final result = entry.actual!;
    try {
      final path = await const AutoscoreDiagnosticExport().save(
        AutoscoreEvidence(entry.evidence!.cameras, {
          ...entry.evidence!.hit,
          'correctionHistoryAnalysis': controller.correctionAnalysis,
        }, capturedAt: entry.evidence!.capturedAt),
        entry.detected.label,
        result.label,
        correctionPosition: entry.correctedPoint == null
            ? null
            : {
                'xMillimetres': entry.correctedPoint!.x,
                'yMillimetres': entry.correctedPoint!.y,
                'source': entry.detectedPoint == null
                    ? 'manualMissingPoint'
                    : 'flatBoard',
              },
      );
      if (!mounted || !identical(entry.actual, result)) return;
      entry.diagnosticPath = path;
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Kamerabilder und Bericht gespeichert. Über „Diagnose-ZIP speichern“ kannst du die Datei weitergeben.',
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Korrektur übernommen, Diagnose konnte nicht gespeichert werden: $e',
            ),
          ),
        );
      }
    }
  }

  Future<void> _export(int index) async {
    if (controller.history[index].diagnosticPath == null) {
      await _saveDiagnostic(index);
    }
    final path = controller.history[index].diagnosticPath;
    if (path == null) return;
    try {
      final location = await getSaveLocation(
        suggestedName: 'autoscore_korrektur_${index + 1}.zip',
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
          const SnackBar(
            content: Text(
              'Diagnose-ZIP gespeichert. Du kannst sie hier zur Analyse anhängen.',
            ),
          ),
        );
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
  void dispose() {
    controller.removeListener(_changed);
    if (widget.controller == null) controller.dispose();
    if (widget.cameraController == null) cameras.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AutoscoringPage(
    title: 'Autoscore-Tester',
    controller: cameras,
    automaticCounting: true,
    automaticVisitDartLimit: null,
    audioThrows: () => controller.throws,
    onBoardCleared: controller.reset,
    acceptLabel: 'Treffer bestätigen',
    onThrow: (result) {
      controller.add(result, evidence: captureAutoscoreEvidence(cameras));
      if (identical(result, AutoscoringController.unresolvedThrow)) {
        controller.review(controller.history.length - 1, result);
      }
      return true;
    },
    summaryBuilder: (context) => Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Autoscore-Demo',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'Board leeren und drei USB-Kameras verbinden. Nach der automatischen Kalibrierung startet die Erkennung selbstständig und zählt geworfene Pfeile. Alle Pfeile herausziehen: Sobald das Board wieder leer und ruhig ist, wird der Punktestand auf null gesetzt und die nächste Aufnahme startet automatisch.',
            ),
            const SizedBox(height: 12),
            FlatBoardView(
              cameras: _flatCameras(controller, cameras),
              markers: [
                for (
                  var i = controller.visitStart;
                  i < controller.history.length;
                  i++
                )
                  if (controller.history[i].point != null)
                    FlatBoardMarker(
                      i,
                      controller.history[i].point!,
                      '${controller.history[i].result.label}${controller.history[i].estimated ? ' · Schätzung' : ''}',
                    ),
              ],
              onMoved: (index, point) async {
                controller.movePoint(index, point);
                await _saveDiagnostic(index);
              },
            ),
            const SizedBox(height: 12),
            Text(
              '${controller.totalPoints} Punkte',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            Text('${controller.throws.length} Treffer'),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
              onPressed: cameras.running && !cameras.waitingForEmpty
                  ? _missed
                  : null,
              icon: const Icon(Icons.add_location_alt_outlined),
              label: const Text('Nicht erkannten Pfeil melden'),
            ),
            const SizedBox(height: 12),
            Text(
              controller.accuracyPercent == null
                  ? 'Genauigkeit: noch keine geprüften Treffer'
                  : 'Genauigkeit: ${controller.accuracyPercent!.toStringAsFixed(1)} %',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(
              '${controller.correctCount} von ${controller.reviewedCount} geprüften Treffern richtig · ${controller.history.length - controller.reviewedCount} ungeprüft',
            ),
            const Text(
              'Beim Herausziehen zählen unkorrigierte Treffer automatisch als richtig. Jede Korrektur zählt als Fehler. Statistik und Diagnosebilder bleiben erhalten.',
            ),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
              onPressed: controller.throws.isEmpty ? null : controller.reset,
              icon: const Icon(Icons.restart_alt),
              label: const Text('Punktestand zurücksetzen'),
            ),
            const SizedBox(height: 8),
            Text(
              'Trefferverlauf',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (controller.history.isEmpty)
              const Text('Noch keine automatisch gezählten Kameratreffer.'),
            for (var i = controller.history.length - 1; i >= 0; i--)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${controller.history[i].result.label} · ${controller.history[i].result.scoredPoints} Punkte${controller.history[i].estimated ? ' · Schätzung' : ''}',
                    ),
                    Text(
                      controller.history[i].actual == null
                          ? 'Automatisch gezählter USB-Kameratreffer'
                          : 'Erkannt: ${controller.history[i].detected.label} · ${controller.history[i].correct ? "Richtig bestätigt" : "Korrigiert"}',
                    ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (!controller.history[i].wasCorrected)
                          TextButton.icon(
                            style: TextButton.styleFrom(
                              minimumSize: const Size(48, 48),
                            ),
                            onPressed: () => controller.confirm(i),
                            icon: const Icon(Icons.check),
                            label: const Text('Richtig erkannt'),
                          ),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(48, 48),
                          ),
                          onPressed: () => _setPosition(i),
                          icon: const Icon(Icons.add_location_alt_outlined),
                          label: Text(
                            controller.history[i].point == null
                                ? 'Fehlenden Punkt setzen'
                                : 'Position setzen',
                          ),
                        ),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(48, 48),
                          ),
                          onPressed: () => _correct(i),
                          icon: const Icon(Icons.edit),
                          label: const Text('Korrigieren'),
                        ),
                        if (controller.history[i].wasCorrected &&
                            controller.history[i].evidence != null)
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(48, 48),
                            ),
                            onPressed: () => _export(i),
                            icon: const Icon(Icons.download),
                            label: const Text('Diagnose-ZIP speichern'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

List<FlatBoardCamera> _flatCameras(
  AutoscoreDemoController controller,
  AutoscoringController cameras,
) {
  final evidence = controller.history.length > controller.visitStart
      ? controller.history.last.evidence
      : null;
  if (evidence != null) {
    return _evidenceCameras(evidence);
  }
  return [
    for (final camera in cameras.cameras)
      if (camera.snapshot != null && camera.calibration != null)
        FlatBoardCamera(camera.snapshot!, camera.calibration!),
  ];
}

List<FlatBoardCamera> _evidenceCameras(AutoscoreEvidence evidence) => [
  for (final camera in evidence.cameras)
    if (camera.metadata['calibration'] is List)
      FlatBoardCamera(
        camera.image,
        BoardCalibration(
          [
            for (final p in camera.metadata['calibration'] as List)
              BoardPoint(
                (p['x'] as num).toDouble(),
                (p['y'] as num).toDouble(),
              ),
          ],
          lens: camera.metadata['lens'] is Map
              ? LensDistortion.fromJson(camera.metadata['lens'] as Map)
              : const LensDistortion(),
        ),
      ),
];

class AutoscoreTesterMenuCard extends StatelessWidget {
  const AutoscoreTesterMenuCard({super.key});
  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: const Icon(Icons.videocam_outlined),
      title: const Text('Autoscore-Tester'),
      subtitle: const Text('Geworfene Pfeile mit drei USB-Kameras erkennen.'),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const AutoscoreDemoPage()),
      ),
    ),
  );
}
