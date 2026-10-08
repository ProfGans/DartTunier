import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_tournament_manager/features/statistics/domain/analytics/statistics_report.dart';
import 'package:dart_tournament_manager/features/statistics/domain/analytics/statistics_metric.dart';

void main() {
  test('synthetic statistics performance audit', () {
    for (final count in [1000, 10000, 50000]) {
      final rows = List.generate(
        count,
        (i) => StatisticsObservation(
          id: '$i',
          playerId: '${i % 100}',
          name: 'Player',
          label: 'Match',
          date: DateTime(2026).add(Duration(minutes: i)),
          values: {
            for (final m in statisticsMetrics) m.id: (i % 100 + 1).toDouble(),
          },
          result: 'S',
        ),
      );
      final samples = <int>[];
      var checksum = 0.0;
      for (var run = 0; run < 7; run++) {
        final watch = Stopwatch()..start();
        final report = StatisticsReport(rows);
        final metric = statisticsMetrics.first;
        final reports = [
          for (var p = 0; p < 100; p++) report.filtered(players: {'$p'}),
        ];
        reports.sort(
          (a, b) => (b.value(metric) ?? 0).compareTo(a.value(metric) ?? 0),
        );
        for (final r in reports) {
          checksum += r.value(metric) ?? 0;
          r.series(metric);
          r.form;
        }
        watch.stop();
        if (run > 1) samples.add(watch.elapsedMicroseconds);
      }
      samples.sort();
      debugPrint(
        'PERF observations=$count players=100 median_ms=${samples[2] / 1000} max_ms=${samples.last / 1000} checksum=$checksum',
      );
    }
  });
}
