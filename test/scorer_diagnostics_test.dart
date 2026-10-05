import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_tournament_manager/features/autoscoring/application/scorer_diagnostics.dart';
import 'package:dart_tournament_manager/features/autoscoring/data/autoscore_diagnostic_export.dart';

void main() {
  test(
    'Deletion diagnosis preserves evidence and shifts subsequent corrections',
    () async {
      final calls = <String>[];
      final c = ScorerDiagnostics(
        save: (e, d, a, p) async {
          calls.add('$d:$a:${p['source']}');
          return 'diagnosis.zip';
        },
      );
      c.record('20', null);
      c.record('5', AutoscoreEvidence([], {}));
      await c.remove(0, const Point(0, -120), AutoscoreEvidence([], {}));
      await c.correct(0, 'T5', const Point(0, -100));
      expect(calls, ['20:Entfernt:manualRemoval', '5:T5:flatBoard']);
      c.dispose();
    },
  );
  test(
    'Missing dart diagnosis preserves missing flag and manually placed point',
    () async {
      final evidence = AutoscoreEvidence([], {'manualMissingReport': true});
      final c = ScorerDiagnostics(
        save: (e, d, a, p) async {
          expect(e.hit['manualMissingReport'], true);
          expect(d, 'Nicht erkannt');
          expect(a, 'T20');
          expect(p['source'], 'manualMissingPoint');
          expect(p['yMillimetres'], -103.0);
          return 'missing.zip';
        },
      );
      c.record('20', null);
      c.insertMissing(0, evidence);
      await c.correct(0, 'T20', const Point(0.0, -103.0));
      expect(c.path, 'missing.zip');
      c.dispose();
    },
  );
  test(
    'Corrections keep original evidence after removal and use corrected coordinates',
    () async {
      final evidence = AutoscoreEvidence([], {'views': 2});
      final calls = <String>[];
      final c = ScorerDiagnostics(
        save: (e, d, a, p) async {
          expect(identical(e, evidence), true);
          expect(d, '20');
          expect(p['xMillimetres'], 0.0);
          calls.add(a);
          return '$a.zip';
        },
      );
      c.record('20', evidence);
      final first = c.correct(0, 'T20', const Point(0.0, -103.0));
      final last = c.correct(0, 'D20', const Point(0.0, -166.0));
      c.nextVisit();
      await Future.wait([first, last]);
      expect(calls, ['T20', 'D20']);
      expect(c.path, 'D20.zip');
      expect(c.saving, false);
      c.dispose();
    },
  );
  test(
    'Unavailable evidence and failed writes are reported without throwing',
    () async {
      final c = ScorerDiagnostics(
        save: (e, d, a, p) async => throw StateError('disk'),
      );
      c.record('20', null);
      await c.correct(0, 'T20', const Point(0.0, -103.0));
      expect(c.error, contains('Keine Kamerabilder'));
      c.nextVisit();
      c.record('20', AutoscoreEvidence([], {}));
      await c.correct(0, 'T20', const Point(0.0, -103.0));
      expect(c.error, contains('Korrektur bleibt'));
      expect(c.path, isNull);
      c.dispose();
    },
  );
}
