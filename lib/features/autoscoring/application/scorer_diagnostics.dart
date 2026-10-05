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
  String? path, error;
  bool saving = false, _disposed = false;
  int _revision = 0;
  Future<void> _queue = Future.value();
  void record(String label, AutoscoreEvidence? evidence) =>
      _visit.add((label, evidence));
  void insertMissing(int index, AutoscoreEvidence? evidence) =>
      _visit.insert(index, ('Nicht erkannt', evidence));
  void nextVisit() => _visit.clear();
  Future<void> correct(int index, String corrected, BoardPoint point) {
    final entry = _visit[index];
    final revision = ++_revision;
    path = null;
    error = null;
    final evidence = entry.$2;
    if (evidence == null) {
      saving = false;
      error = 'Keine Kamerabilder für diesen Dart verfügbar.';
      notifyListeners();
      return Future.value();
    }
    saving = true;
    notifyListeners();
    final position = <String, Object?>{
      'xMillimetres': point.x,
      'yMillimetres': point.y,
      'source': entry.$1 == 'Nicht erkannt'
          ? 'manualMissingPoint'
          : 'flatBoard',
    };
    _queue = _queue.then((_) async {
      try {
        final saved = await _save(evidence, entry.$1, corrected, position);
        if (!_disposed && revision == _revision) path = saved;
      } catch (_) {
        if (!_disposed && revision == _revision) {
          error =
              'Diagnose konnte nicht gespeichert werden. Korrektur bleibt übernommen.';
        }
      } finally {
        if (!_disposed && revision == _revision) {
          saving = false;
          notifyListeners();
        }
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
