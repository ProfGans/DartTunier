import 'package:flutter/material.dart';
import '../../../../shared/widgets/adaptive_content.dart';
import '../../domain/analytics/statistics_metric.dart';
import '../../domain/analytics/statistics_report.dart';
import '../../domain/statistics_period.dart';
import '../statistics_period_filter.dart';
import 'statistics_line_chart.dart';

class StatisticsMetricPage extends StatefulWidget {
  const StatisticsMetricPage({
    super.key,
    required this.report,
    required this.metric,
    required this.subject,
  });
  final StatisticsReport report;
  final StatisticsMetric metric;
  final String subject;
  @override
  State<StatisticsMetricPage> createState() => _MetricState();
}

class _MetricState extends State<StatisticsMetricPage> {
  StatisticsPeriod? period;
  String periodLabel = 'Gesamt', mode = 'Einzelwerte';
  int? selected, startScore;
  String date(DateTime value) {
    final d = value.toLocal();
    return '${d.day}.${d.month}.${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final metric = widget.metric;
    final report = StatisticsReport(
      widget.report
          .filtered(period: period)
          .observations
          .where((o) => startScore == null || o.startScore == startScore),
    );
    final series = report.series(metric);
    final chart = series.reversed.take(30).toList().reversed.toList();
    final trend = report.trend(metric);
    final distribution = report.distribution(metric);
    final histogram = report.histogram(metric);
    final values = [
      for (final point in chart)
        mode == 'Einzelwerte'
            ? point.$2
            : report.value(
                metric,
                series.take(series.indexOf(point) + 1).map((p) => p.$1),
              )!,
    ];
    final index = (selected ?? (chart.length - 1)).clamp(
      0,
      chart.isEmpty ? 0 : chart.length - 1,
    );
    final opponents = <String, List<StatisticsObservation>>{};
    for (final o in report.observations) {
      if (o.opponent.isNotEmpty) {
        opponents.putIfAbsent(o.opponent, () => []).add(o);
      }
    }
    return Scaffold(
      appBar: AppBar(title: Text(metric.title)),
      body: AdaptiveContentList(
        children: [
          Text(widget.subject, style: Theme.of(context).textTheme.titleLarge),
          Text(metric.explanation),
          StatisticsPeriodFilter(
            selected: periodLabel,
            period: period,
            onChanged: (label, value) => setState(() {
              periodLabel = label;
              period = value;
              selected = null;
            }),
          ),
          if (widget.report.observations
              .map((o) => o.startScore)
              .whereType<int>()
              .toSet()
              .isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Alle Startpunktzahlen'),
                  selected: startScore == null,
                  onSelected: (_) => setState(() {
                    startScore = null;
                    selected = null;
                  }),
                ),
                for (final score
                    in widget.report.observations
                        .map((o) => o.startScore)
                        .whereType<int>()
                        .toSet()
                        .toList()
                      ..sort())
                  ChoiceChip(
                    label: Text('$score Punkte'),
                    selected: startScore == score,
                    onSelected: (_) => setState(() {
                      startScore = score;
                      selected = null;
                    }),
                  ),
              ],
            ),
          const SizedBox(height: 16),
          AdaptiveTileLayout(
            children: [
              _ValueCard('Gesamtwert', metric.format(report.value(metric))),
              _ValueCard(
                'Datenbasis',
                '${series.length} mit Messwert · ${report.observations.length - series.length} ohne Messwert',
              ),
              _ValueCard(
                'Jüngste ${trend.recentCount} Begegnungen',
                metric.format(trend.recent),
              ),
              _ValueCard(
                'Vorherige ${trend.previousCount} Begegnungen',
                metric.format(trend.previous),
              ),
            ],
          ),
          if (trend.delta != null)
            Text(
              'Veränderung: ${trend.delta! >= 0 ? '+' : ''}${trend.delta!.toStringAsFixed(2)}${metric.unit == '%'
                  ? ' Prozentpunkte'
                  : metric.unit.isEmpty
                  ? ''
                  : ' ${metric.unit}'}${metric.lowerIsBetter ? ' · niedrigere Werte sind günstiger' : ''}',
            ),
          const Text(
            'Formvergleich: bis zu fünf jüngste messbare Begegnungen gegen die bis zu fünf davor. Kleine Stichproben und unterschiedliche Gegner sind keine sichere Leistungsprognose.',
          ),
          if (metric.title == 'Checkoutquote' &&
              report.observations.any(
                (o) => (o.values['unknownAttempts'] ?? 0) > 0,
              ))
            const Text(
              'Die Gesamtquote ist wegen unbekannter Checkoutversuche nicht verfügbar. Der Verlauf zeigt nur Begegnungen mit vollständig erfassten Versuchen.',
            ),
          const SizedBox(height: 24),
          Text('Verlauf', style: Theme.of(context).textTheme.titleLarge),
          Wrap(
            spacing: 8,
            children: [
              for (final value in ['Einzelwerte', 'Gesamtentwicklung'])
                ChoiceChip(
                  label: Text(value),
                  selected: mode == value,
                  onSelected: (_) => setState(() => mode = value),
                ),
            ],
          ),
          const Text(
            'Die Grafik zeigt die letzten 30 messbaren Begegnungen in zeitlicher Reihenfolge. Gesamtentwicklung zeigt den bis dahin erreichten Gesamtwert. Spiele ohne Messwert werden übersprungen.',
          ),
          StatisticsLineChart(
            values: values,
            description: '${metric.title}, $mode',
            selected: chart.isEmpty ? null : index,
            onSelected: (i) => setState(() => selected = i),
          ),
          if (chart.isNotEmpty) ...[
            const SizedBox(height: 8),
            DropdownButtonFormField<int>(
              initialValue: index,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Messpunkt auswählen',
              ),
              items: [
                for (var i = 0; i < chart.length; i++)
                  DropdownMenuItem(
                    value: i,
                    child: Text(
                      '${date(chart[i].$1.date)} · ${metric.format(values[i])}',
                    ),
                  ),
              ],
              onChanged: (value) => setState(() => selected = value),
              key: ValueKey('$periodLabel-$startScore-$mode-$index'),
            ),
            Text(
              '${chart[index].$1.label}\n${chart[index].$1.estimatedDate ? 'Turnierdatum (Spielzeit fehlt)' : 'Spielzeit'}: ${date(chart[index].$1.date)}',
            ),
          ],
          const SizedBox(height: 24),
          Text(
            'Bestwerte & Konstanz',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          AdaptiveTileLayout(
            children: [
              _ValueCard('Minimum', metric.format(distribution.min)),
              _ValueCard('Maximum', metric.format(distribution.max)),
              _ValueCard('Median', metric.format(distribution.median)),
              _ValueCard(
                'Streuung der Einzelwerte',
                distribution.deviation?.toStringAsFixed(2) ?? '—',
              ),
            ],
          ),
          const Text(
            'Die Streuung ist die Standardabweichung der Einzelwerte, nicht des gewichteten Gesamtwerts. Kleinere Streuung bedeutet gleichmäßigere Werte.',
          ),
          if (histogram.isNotEmpty) ...[
            Text(
              'Verteilung der Spielwerte',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            for (final bucket in histogram)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${bucket.lower.toStringAsFixed(2)} – ${bucket.upper.toStringAsFixed(2)}: ${bucket.count} Begegnungen',
                    ),
                    LinearProgressIndicator(
                      value: bucket.count / series.length,
                      minHeight: 8,
                    ),
                  ],
                ),
              ),
          ],
          if (opponents.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text(
              'Gegneranalyse',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const Text(
              'Gruppiert nach den gespeicherten Gegnernamen. Bei gleichen Namen kann die Zuordnung mehrdeutig sein.',
            ),
            for (final entry in opponents.entries)
              ListTile(
                title: Text(entry.key),
                subtitle: Text(
                  '${entry.value.length} Begegnungen · ${entry.value.where((o) => o.result == 'S').length} Siege',
                ),
                trailing: Text(
                  metric.format(report.value(metric, entry.value)),
                ),
              ),
          ],
          const SizedBox(height: 24),
          Text(
            'Alle Einzelwerte',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          if (report.observations.isEmpty)
            const Text('Keine Daten im gewählten Zeitraum.'),
          for (final o in report.observations.reversed)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(o.label),
                    Text(
                      '${date(o.date)}${o.estimatedDate ? ' · Turnierdatum' : ''}${o.result == null ? ' · laufend/unvollständig' : ''}',
                    ),
                    Text(
                      metric.format(report.value(metric, [o])),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ValueCard extends StatelessWidget {
  const _ValueCard(this.label, this.value);
  final String label, value;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label),
          Text(value, style: Theme.of(context).textTheme.titleLarge),
        ],
      ),
    ),
  );
}
