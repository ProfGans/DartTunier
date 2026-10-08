import '../../../shared/widgets/paged_entries.dart';
import '../../statistics/presentation/heatmap/cockpit_heatmap_section.dart';
import 'package:flutter/material.dart';
import '../../../shared/widgets/adaptive_content.dart';
import '../../statistics/domain/analytics/statistics_report.dart';
import '../../statistics/domain/analytics/statistics_metric.dart';
import '../../statistics/domain/statistics_period.dart';
import '../../statistics/presentation/statistics_period_filter.dart';
import '../../statistics/presentation/analytics/statistics_metric_page.dart';
import '../../statistics/presentation/analytics/player_analytics_page.dart';
import '../domain/community_statistics.dart';

class CommunityAnalyticsPage extends StatefulWidget {
  const CommunityAnalyticsPage({
    super.key,
    required this.name,
    required this.data,
    this.embedded = false,
    this.actions = const [],
  });
  final String name;
  final CommunityStatistics data;
  final bool embedded;
  final List<Widget> actions;
  @override
  State<CommunityAnalyticsPage> createState() => _CommunityAnalyticsState();
}

class _CommunityAnalyticsState extends State<CommunityAnalyticsPage> {
  late StatisticsReport all = _loadReport();
  StatisticsReport _loadReport() => const StatisticsAnalytics().tournaments(
    widget.data.tournaments,
    aliases: widget.data.aliases,
  );
  @override
  void didUpdateWidget(covariant CommunityAnalyticsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Parent supplies a fresh snapshot after reload or result corrections.
    all = _loadReport();
  }

  StatisticsPeriod? period;
  String periodLabel = 'Gesamt';
  int metricIndex = 4;
  bool? doubles;
  @override
  Widget build(BuildContext context) {
    final report = all.filtered(period: period, doubleMatch: doubles);
    final metric = statisticsMetrics[metricIndex];
    final players = {
      for (final player in widget.data.players) player.id: player.name,
      for (final o in report.observations) o.playerId: o.name,
    };
    final ranked =
        [
          for (final player in players.entries)
            (
              id: player.key,
              name: player.value,
              report: report.byPlayer[player.key] ?? StatisticsReport(const []),
            ),
        ]..sort((a, b) {
          final x = a.report.value(metric), y = b.report.value(metric);
          if (x == null) return y == null ? a.name.compareTo(b.name) : 1;
          if (y == null) return -1;
          final order = metric.lowerIsBetter ? x.compareTo(y) : y.compareTo(x);
          return order == 0 ? a.name.compareTo(b.name) : order;
        });
    final maximum = ranked
        .map((p) => p.report.value(metric))
        .whereType<double>()
        .fold<double>(0, (largest, value) => value > largest ? value : largest);
    final body = AdaptiveContentList(
      children: [
        ...widget.actions,
        Text(widget.name, style: Theme.of(context).textTheme.headlineSmall),
        const Text(
          'Für jede Kennzahl: Spielervergleich, Form, Verlauf und ausführliche Einzelwerte. Ausschließlich Ergebnisse dieser Community; private Scorer-Spiele werden nicht veröffentlicht.',
        ),
        StatisticsPeriodFilter(
          selected: periodLabel,
          period: period,
          onChanged: (label, p) => setState(() {
            periodLabel = label;
            period = p;
          }),
        ),
        Wrap(
          spacing: 8,
          children: [
            for (final entry in <bool?, String>{
              null: 'Alle Begegnungen',
              false: 'Einzel',
              true: 'Doppel',
            }.entries)
              ChoiceChip(
                label: Text(entry.value),
                selected: doubles == entry.key,
                onSelected: (_) => setState(() => doubles = entry.key),
              ),
          ],
        ),
        const SizedBox(height: 16),
        CockpitHeatmapSection(
          subject: widget.name,
          community: true,
          period: period,
        ),
        DropdownButtonFormField<int>(
          initialValue: metricIndex,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Kennzahl vergleichen'),
          items: [
            for (var i = 0; i < statisticsMetrics.length; i++)
              DropdownMenuItem(
                value: i,
                child: Text(statisticsMetrics[i].title),
              ),
          ],
          onChanged: (i) {
            if (i != null) setState(() => metricIndex = i);
          },
        ),
        Text(metric.explanation),
        if (metric.category != 'Ergebnisse' &&
            metric.category != 'Legs & Sets') ...[
          Text("Community-Gesamtwert: ${metric.format(report.value(metric))}"),
          const Text(
            'Zusammenfassung aller Spielerbeiträge dieser Community. Eine Begegnung kann Werte für beide Spieler liefern.',
          ),
          TextButton.icon(
            icon: const Icon(Icons.show_chart),
            label: const Text('Community-Verlauf öffnen'),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => StatisticsMetricPage(
                  report: report,
                  metric: metric,
                  subject: "Alle Spielerbeiträge · ${widget.name}",
                ),
              ),
            ),
          ),
        ],
        const Text(
          'Quoten werden gewichtet berechnet. Unterschiedliche Spielzahlen, Startpunktzahlen und fehlende Scorer-Daten beim Vergleich beachten. Zählwerte sind keine Spielstärke-Rangliste.',
        ),
        const SizedBox(height: 16),
        if (report.observations.isEmpty)
          const Text('Keine erfassten Begegnungen im gewählten Zeitraum.'),
        PagedEntries<({String id, String name, StatisticsReport report})>(
          key: ValueKey('$periodLabel-$period-$doubles-$metricIndex'),
          entries: ranked,
          builder: (player) => Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    player.name,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Text(
                    metric.format(player.report.value(metric)),
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  Text(
                    '${player.report.completed.length} abgeschlossene Spiele · ${player.report.series(metric).length} Begegnungen mit Messwert',
                  ),
                  if (player.report.value(metric) != null) ...[
                    LinearProgressIndicator(
                      value: maximum == 0
                          ? 0
                          : player.report.value(metric)! / maximum,
                      minHeight: 8,
                      semanticsLabel: player.name,
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (player.report.form.isNotEmpty)
                    Text(
                      'Form: ${player.report.form.join(' · ')} · S = Sieg, U = Remis, N = Niederlage',
                    ),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      TextButton.icon(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => StatisticsMetricPage(
                              report: player.report,
                              metric: metric,
                              subject: '${player.name} · ${widget.name}',
                            ),
                          ),
                        ),
                        icon: const Icon(Icons.show_chart),
                        label: Text('${metric.title} im Detail'),
                      ),
                      OutlinedButton(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => PlayerAnalyticsPage(
                              community: true,
                              name: player.name,
                              tournaments: all.filtered(players: {player.id}),
                            ),
                          ),
                        ),
                        child: const Text('Alle Spielerstatistiken'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
    return widget.embedded
        ? body
        : Scaffold(
            appBar: AppBar(title: const Text('Community-Statistik-Cockpit')),
            body: body,
          );
  }
}
