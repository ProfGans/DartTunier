import '../../../../shared/widgets/sport_section_navigation.dart';
import 'package:flutter/material.dart';
import '../../../../shared/widgets/adaptive_content.dart';
import '../../domain/analytics/statistics_report.dart';
import '../../domain/statistics_period.dart';
import '../statistics_period_filter.dart';
import 'statistics_dashboard.dart';
import '../heatmap/cockpit_heatmap_section.dart';
import '../../data/scorer_heatmap_repository.dart';

class PlayerAnalyticsPage extends StatefulWidget {
  const PlayerAnalyticsPage({
    super.key,
    required this.name,
    required this.tournaments,
    this.scorer,
    this.heatmapSessions,
    this.community = false,
    this.embedded = false,
    this.header = const [],
    this.footerBuilder,
  });
  final String name;
  final bool community;
  final StatisticsReport tournaments;
  final StatisticsReport? scorer;
  final List<ScorerHeatmapSession>? heatmapSessions;
  final bool embedded;
  final List<Widget> header;
  final List<Widget> Function(StatisticsPeriod? period)? footerBuilder;
  @override
  State<PlayerAnalyticsPage> createState() => _AnalyticsState();
}

class _AnalyticsState extends State<PlayerAnalyticsPage> {
  StatisticsPeriod? period;
  String periodLabel = 'Gesamt';
  bool scorer = true;
  bool? doubles;
  @override
  Widget build(BuildContext context) {
    final useScorer = scorer && widget.scorer != null;
    final report = (useScorer ? widget.scorer! : widget.tournaments).filtered(
      period: period,
      doubleMatch: doubles,
    );
    final body = AdaptiveContentList(
      children: [
        ...widget.header,
        Text(widget.name, style: Theme.of(context).textTheme.headlineSmall),
        StatisticsPeriodFilter(
          selected: periodLabel,
          period: period,
          onChanged: (label, p) => setState(() {
            periodLabel = label;
            period = p;
          }),
        ),
        if (widget.scorer != null) ...[
          const SizedBox(height: 12),
          SportSectionNavigation<bool>(
            label: 'Statistikbereich',
            selected: useScorer,
            sections: const [
              SportSection(true, 'Meine Scorer-Spiele', Icons.sports_score),
              SportSection(
                false,
                'Turnierergebnisse',
                Icons.emoji_events_outlined,
              ),
            ],
            onChanged: (value) => setState(() {
              scorer = value;
              if (value) doubles = null;
            }),
          ),
        ],
        if (!useScorer) ...[
          const SizedBox(height: 12),
          SportSectionNavigation<int>(
            label: 'Begegnungen',
            selected: doubles == null
                ? 0
                : doubles!
                ? 2
                : 1,
            sections: const [
              SportSection(0, 'Alle Begegnungen', Icons.view_list_outlined),
              SportSection(1, 'Einzel', Icons.person_outline),
              SportSection(2, 'Doppel', Icons.people_outline),
            ],
            onChanged: (value) =>
                setState(() => doubles = value == 0 ? null : value == 2),
          ),
        ],
        const SizedBox(height: 12),
        Text(
          useScorer
              ? 'Persönlich zugeordnete Scorer-Sitzungen. Laufende Sitzungen tragen Aufnahme-Statistiken bei.'
              : 'Über die gespeicherten Profil-IDs zugeordnete Turnierergebnisse. Nur übertragene Scorer-Aufnahmen ermöglichen Scoring- und Checkoutwerte.',
        ),
        if (widget.scorer != null)
          const Text(
            'Scorer-Spiele und Turnierergebnisse werden getrennt ausgewertet, damit ein übertragenes Spiel nicht doppelt zählt.',
          ),
        const SizedBox(height: 16),
        CockpitHeatmapSection(
          subject: widget.name,
          community: widget.community,
          sessions: useScorer ? widget.heatmapSessions : null,
          period: period,
        ),
        StatisticsDashboard(
          report: report,
          title: 'Statistik · ${widget.name}',
        ),
        ...?widget.footerBuilder?.call(period),
      ],
    );
    return widget.embedded
        ? body
        : Scaffold(
            appBar: AppBar(title: const Text('Statistik-Cockpit')),
            body: body,
          );
  }
}
