import 'package:flutter/foundation.dart';
import '../data/autoscore_diagnostic_export.dart';
import '../domain/board_geometry.dart';

typedef SaveScorerDiagnostic =
    Future<String> Function(
      AutoscoreEvidence evidence,
      String detected,
      String corrected,
      Map<String, Object?> position,
    );

class ScorerDiagnostics extends ChangeNotifier {
  ScorerDiagnostics({SaveScorerDiagnostic? save})
    : _save = save ?? _defaultSave;
  final SaveScorerDiagnostic _save;
  static Future<String> _defaultSave(
    AutoscoreEvidence e,
    String d,
    String c,
    Map<String, Object?> p,
  ) => const AutoscoreDiagnosticExport().save(e, d, c, correctionPosition: p);
  final _visit = <(String, AutoscoreEvidence?)>[];
  final _statuses = <_DartDiagnostic>[];
  String? pathAt(int index) =>
      index < _statuses.length ? _statuses[index].path : null;
  String? errorAt(int index) =>
      index < _statuses.length ? _statuses[index].error : null;
  bool savingAt(int index) =>
      index < _statuses.length && _statuses[index].saving;
  String? path, error;
  bool saving = false, _disposed = false;
  int _revision = 0;
  Future<void> _queue = Future.value();
  void record(String label, AutoscoreEvidence? evidence) {
    _visit.add((label, evidence));
    _statuses.add(_DartDiagnostic());
  }

  void insertMissing(int index, AutoscoreEvidence? evidence) {
    _visit.insert(index, ('Nicht erkannt', evidence));
    _statuses.insert(index, _DartDiagnostic());
  }

  void nextVisit() {
    _visit.clear();
    _statuses.clear();
  }

  Future<void> remove(
    int index,
    BoardPoint point,
    AutoscoreEvidence? fallback,
  ) {
    final entry = _visit[index];
    _visit[index] = (entry.$1, entry.$2 ?? fallback);
    final saved = correct(index, 'Entfernt', point, source: 'manualRemoval');
    _visit.removeAt(index);
    _statuses.removeAt(index);
    return saved;
  }

  Future<void> correct(
    int index,
    String corrected,
    BoardPoint point, {
    String? source,
  }) {
    final entry = _visit[index];
    final status = _statuses[index];
    final dartRevision = ++status.revision;
    status.path = null;
    status.error = null;
    final revision = ++_revision;
    path = null;
    error = null;
    final evidence = entry.$2;
    if (evidence == null) {
      saving = false;
      error = 'Keine Kamerabilder für diesen Dart verfügbar.';
      status.error = error;
      status.saving = false;
      notifyListeners();
      return Future.value();
    }
    saving = true;
    status.saving = true;
    notifyListeners();
    final position = <String, Object?>{
      if (source == 'manualRemoval') ...{
        'removedXMillimetres': point.x,
        'removedYMillimetres': point.y,
      } else ...{
        'xMillimetres': point.x,
        'yMillimetres': point.y,
      },
      'source':
          source ??
          (entry.$1 == 'Nicht erkannt' ? 'manualMissingPoint' : 'flatBoard'),
    };
    _queue = _queue.then((_) async {
      try {
        final saved = await _save(evidence, entry.$1, corrected, position);
        if (dartRevision == status.revision) status.path = saved;
        if (!_disposed && revision == _revision) path = saved;
      } catch (_) {
        if (dartRevision == status.revision) {
          status.error = 'Diagnose konnte nicht gespeichert werden.';
        }
        if (!_disposed && revision == _revision) {
          error =
              'Diagnose konnte nicht gespeichert werden. Korrektur bleibt übernommen.';
        }
      } finally {
        if (dartRevision == status.revision) status.saving = false;
        if (!_disposed && revision == _revision) {
          saving = false;
        }
        if (!_disposed) notifyListeners();
      }
    });
    return _queue;
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

class _DartDiagnostic {
  String? path, error;
  bool saving = false;
  int revision = 0;
}
