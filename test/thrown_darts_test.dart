import 'package:flutter_test/flutter_test.dart';
import 'package:dart_tournament_manager/features/scorer/application/scorer_controller.dart';
import 'package:dart_tournament_manager/features/scorer/domain/scorer_settings.dart';
import 'package:dart_tournament_manager/features/scorer/domain/x01/x01_rules.dart';
import 'package:dart_tournament_manager/features/statistics/domain/saved_scorer_match.dart';
import 'package:dart_tournament_manager/features/statistics/domain/analytics/statistics_report.dart';
import 'package:dart_tournament_manager/features/statistics/domain/analytics/statistics_metric.dart';

void main() {
  const rules = X01Rules();
  final settings = ScorerSettings(
    startScore: 40,
    participants: const [ScorerParticipant('A'), ScorerParticipant('B')],
  );
  SavedScorerMatch snapshot(ScorerController c) => SavedScorerMatch(
    id: 'session',
    accountId: 'owner',
    playedAt: DateTime.utc(2026, 10, 8),
    playerIndex: 0,
    names: const ['A', 'B'],
    startScores: const [40, 40],
    standard501Rules: false,
    doubleOut: true,
    visits: c.statisticsVisits,
    pendingDarts: c.activePlayer == 0 ? c.visit.length : 0,
    winner: c.winner,
  );
  test(
    'partial misses count without positions; undo and replay preserve actual bust count',
    () {
      final c = ScorerController(settings)..throwDart(rules.createMiss());
      expect(c.hits, isEmpty);
      var saved = snapshot(c);
      expect(saved.thrownDarts, 1);
      expect(saved.statistics.darts, 0);
      final metric = statisticsMetrics.firstWhere(
        (m) => m.id == 'thrownDarts',
      );
      expect(const StatisticsAnalytics().scorer([saved]).value(metric), 1);
      c.throwDart(rules.createTriple(20));
      saved = SavedScorerMatch.fromJson(snapshot(c).toJson());
      expect(saved.thrownDarts, 2);
      expect(saved.statistics.darts, 3);
      expect(saved.estimatedThrownDarts, 0);
      final restored = ScorerController(settings)
        ..restoreActions(c.exportActions());
      expect(snapshot(restored).thrownDarts, 2);
      restored.undo();
      expect(snapshot(restored).thrownDarts, 1);
      restored.undo();
      expect(snapshot(restored).thrownDarts, 0);
      c.dispose();
      restored.dispose();
    },
  );
  test('opponent darts are excluded, manual totals are marked estimated', () {
    final c = ScorerController(settings)..submitScore(20);
    expect(snapshot(c).thrownDarts, 3);
    expect(snapshot(c).estimatedThrownDarts, 3);
    c.throwDart(rules.createMiss());
    c.throwDart(rules.createTriple(20));
    expect(snapshot(c).thrownDarts, 3);
    c.dispose();
    final finish = ScorerController(settings)
      ..submitScore(40, checkoutDarts: 1);
    expect(snapshot(finish).thrownDarts, 1);
    expect(snapshot(finish).estimatedThrownDarts, 0);
    finish.dispose();
  });
  test('legacy snapshots remain readable and estimates are explicit', () {
    final c = ScorerController(settings)..throwDart(rules.createTriple(20));
    final old = snapshot(c).toJson()
      ..['schemaVersion'] = 2
      ..remove('pendingDarts');
    for (final visit in old['visits'] as List) {
      (visit as Map).remove('thrownDarts');
    }
    final loaded = SavedScorerMatch.fromJson(old);
    expect(loaded.thrownDarts, 3);
    expect(loaded.estimatedThrownDarts, 3);
    c.dispose();
  });
}
