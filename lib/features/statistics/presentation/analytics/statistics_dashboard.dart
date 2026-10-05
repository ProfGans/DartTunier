import 'package:flutter/material.dart';
import '../../../../shared/widgets/adaptive_content.dart';
import '../../domain/analytics/statistics_metric.dart';
import '../../domain/analytics/statistics_report.dart';
import 'statistics_metric_page.dart';
import 'statistics_line_chart.dart';

class StatisticsDashboard extends StatefulWidget {
  const StatisticsDashboard({
    super.key,
    required this.report,
    required this.title,
  });
  final StatisticsReport report;
  final String title;
  @override
  State<StatisticsDashboard> createState() => _DashboardState();
}

class _DashboardState extends State<StatisticsDashboard>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  String category = 'Ergebnisse';
  @override
  Widget build(BuildContext context) {
    super.build(context);
    final report = widget.report;
    final form = report.form;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(widget.title, style: Theme.of(context).textTheme.titleLarge),
        const Text(
          'Kennzahl öffnen für Verlauf, Formvergleich, Gegneranalyse und Einzelwerte.',
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Aktuelle Form',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (form.isEmpty)
                  const Text('Noch keine abgeschlossenen Spiele.')
                else ...[
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final result in form)
                        Chip(
                          label: Text(
                            result == 'S'
                                ? 'Sieg'
                                : result == 'U'
                                ? 'Remis'
                                : 'Niederlage',
                          ),
                          avatar: Icon(
                            result == 'S'
                                ? Icons.check
                                : result == 'U'
                                ? Icons.remove
                                : Icons.close,
                            size: 18,
                          ),
                        ),
                    ],
                  ),
                  Text(
                    'Letzte ${form.length} Spiele · ältestes links · ${report.winningStreak} Siege in Folge',
                  ),
                ],
                Text(
                  '${report.observations.length} erfasste Begegnungen/Sitzungen · ${report.observations.where((o) => o.values.containsKey('visits')).length} mit Scorer-Aufnahmen',
                ),
                if (report.observations.any((o) => o.estimatedDate))
                  const Text(
                    'Ältere Ergebnisse ohne Spielzeit erscheinen nur unter Gesamt. Ihr Verlauf und ihre Reihenfolge orientieren sich am Turnierdatum.',
                  ),
                if (report.observations
                        .map((o) => o.startScore)
                        .whereType<int>()
                        .toSet()
                        .length >
                    1)
                  const Text(
                    'Mehrere Startpunktzahlen enthalten. Legqualität ist dadurch nur eingeschränkt vergleichbar.',
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final group
                in statisticsMetrics.map((m) => m.category).toSet())
              ChoiceChip(
                label: Text(group),
                selected: category == group,
                onSelected: (_) => setState(() => category = group),
              ),
          ],
        ),
        const SizedBox(height: 16),
        AdaptiveTileLayout(
          minTileWidth: 330,
          children: [
            for (final metric in statisticsMetrics.where(
              (m) => m.category == category,
            ))
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        metric.title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        metric.format(report.value(metric)),
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      Text(
                        '${report.series(metric).length} Begegnungen mit Messwert',
                      ),
                      if (report.series(metric).isNotEmpty)
                        StatisticsLineChart(
                          values: report
                              .series(metric)
                              .reversed
                              .take(15)
                              .toList()
                              .reversed
                              .map((p) => p.$2)
                              .toList(),
                          description: 'Kurzverlauf ${metric.title}',
                        ),
                      TextButton.icon(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => StatisticsMetricPage(
                              report: report,
                              metric: metric,
                              subject: widget.title,
                            ),
                          ),
                        ),
                        icon: const Icon(Icons.query_stats),
                        label: Text('${metric.title} im Detail'),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
