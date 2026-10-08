import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'autoscore_demo_controller.dart';
import '../data/autoscore_diagnostic_export.dart';

/// Opt-in collection of correct and incorrect throws, independently of scoring.
class AutoscoreValidationSeries extends ChangeNotifier {
  AutoscoreValidationSeries({this.outputRoot});
  final Directory? outputRoot;
  bool _manifestQueued = false;
  Future<Directory> _directory(String id) async => Directory(
    '${outputRoot?.path ?? '${(await getApplicationDocumentsDirectory()).path}/Autoscore-Pruefserien'}/$id',
  );
  Future<void> _writeManifest(String id) async {
    final root = await _directory(id);
    await root.create(recursive: true);
    folder = root.path;
    await File('${root.path}/pruefserie.json').writeAsString(
      const JsonEncoder.withIndent('  ').convert({
        'schemaVersion': 1,
        'sessionId': id,
        'category': category,
        'split': split,
        'independentlyReviewed': independentlyReviewed,
        'independentlyCorrect': independentlyCorrect,
        'droppedExports': dropped,
        'automaticConfirmationsAreNotIndependentGroundTruth': true,
        'events': _events,
      }),
    );
  }

  void _persistManifest() {
    if (sessionId == null || _manifestQueued) return;
    final id = sessionId!;
    _manifestQueued = true;
    pending++;
    _queue = _queue.then((_) async {
      try {
        await _writeManifest(id);
      } catch (e) {
        error = 'Prüfserie konnte nicht gespeichert werden: $e';
      } finally {
        _manifestQueued = false;
        pending--;
        if (!_disposed) notifyListeners();
      }
    });
  }

  bool active = false;
  String? sessionId, folder, error;
  String category = 'normal', split = 'test';
  int pending = 0, dropped = 0;
  int _start = 0;
  bool _disposed = false;
  final _events = <Map<String, Object?>>[];
  final _signatures = <int, String>{};
  Future<void> _queue = Future.value();
  List<Map<String, Object?>> get events => List.unmodifiable(_events);
  int get independentlyReviewed => _events
      .where(
        (e) =>
            e['verificationSource'] == 'manualConfirmation' ||
            e['verificationSource'] == 'manualCorrection',
      )
      .length;
  int get independentlyCorrect => _events
      .where(
        (e) =>
            e['verificationSource'] == 'manualConfirmation' &&
            e['correct'] == true,
      )
      .length;
  void start(
    int historyLength, {
    required String scenario,
    required String partition,
  }) {
    if (pending > 0) return;
    _start = historyLength;
    category = scenario;
    split = partition;
    sessionId = DateTime.now().toUtc().microsecondsSinceEpoch.toString();
    folder = null;
    error = null;
    dropped = 0;
    _events.clear();
    _signatures.clear();
    active = true;
    notifyListeners();
  }

  void stop() {
    active = false;
    _persistManifest();
    notifyListeners();
  }

  void observe(List<ReviewedAutoscoreThrow> history) {
    if (sessionId == null) return;
    for (var i = _start; i < history.length; i++) {
      if (!active && i - _start >= _events.length) break;
      final entry = history[i];
      final rowIndex = i - _start;
      if (rowIndex >= _events.length) {
        _events.add({
          'index': i + 1,
          'capturedAtUtc': entry.evidence?.capturedAt.toIso8601String(),
          'detected': entry.detected.label,
          'diagnosticPath': null,
        });
        entry.evidence?.hit.addAll({
          'validationSession': sessionId,
          'validationCategory': category,
          'datasetSplit': split,
        });
      }
      final row = _events[rowIndex];
      row.addAll({
        'actual': entry.actual?.label,
        'correct': entry.actual == null ? null : entry.correct,
        'verificationSource': entry.verificationSource,
        'missing': entry.detected.label == 'Nicht erkannt',
        'ignored': entry.ignored,
      });
      final signature =
          '${entry.actual?.label}/${entry.verificationSource}/${entry.correctedPoint}/${entry.ignored}/${entry.evidence?.hit['cameraTrainingLabels']}';
      if (_signatures[i] == signature) continue;
      _signatures[i] = signature;
      if (entry.actual == null) continue;
      final evidence = entry.evidence;
      if (evidence == null) {
        row['exportError'] = 'Keine Aufnahme';
        continue;
      }
      if (pending >= 8) {
        dropped++;
        row['exportError'] = 'Exportwarteschlange voll';
        continue;
      }
      final capturedSession = sessionId!,
          capturedCategory = category,
          capturedSplit = split;
      final copy = AutoscoreEvidence(evidence.cameras, {
        ...evidence.hit,
        'eventType': 'validationThrow',
        'validationSession': capturedSession,
        'validationCategory': capturedCategory,
        'datasetSplit': capturedSplit,
        'verificationSource': entry.verificationSource,
      }, capturedAt: evidence.capturedAt);
      final detected = entry.detected.label, actual = entry.actual!.label;
      final correction = entry.correctedPoint;
      pending++;
      _queue = _queue.then((_) async {
        try {
          final root = await _directory(capturedSession);
          final path = await const AutoscoreDiagnosticExport().save(
            copy,
            detected,
            actual,
            directory: root,
            correctionPosition: correction == null
                ? null
                : {
                    'xMillimetres': correction.x,
                    'yMillimetres': correction.y,
                    'source': 'validationManualCorrection',
                  },
          );
          row['diagnosticPath'] = path;
          folder = root.path;
          await File('${root.path}/pruefserie.json').writeAsString(
            const JsonEncoder.withIndent('  ').convert({
              'schemaVersion': 1,
              'sessionId': capturedSession,
              'category': capturedCategory,
              'split': capturedSplit,
              'independentlyReviewed': independentlyReviewed,
              'independentlyCorrect': independentlyCorrect,
              'droppedExports': dropped,
              'automaticConfirmationsAreNotIndependentGroundTruth': true,
              'events': _events,
            }),
          );
        } catch (e) {
          error = 'Prüfserie konnte nicht gespeichert werden: $e';
          row['exportError'] = e.toString();
        } finally {
          pending--;
          if (!_disposed) notifyListeners();
        }
      });
    }
    _persistManifest();
    if (!_disposed) notifyListeners();
  }

  Future<void> get flush => _queue;
  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
