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
    this.favoriteDouble = '',
    this.communityReports = const {},
    this.communityNames = const {},
    this.heatmapSessions,
    this.community = false,
    this.embedded = false,
    this.header = const [],
    this.footerBuilder,
  });
  final String name, favoriteDouble;
  final bool community;
  final StatisticsReport tournaments;
  final StatisticsReport? scorer;
  final Map<String, StatisticsReport> communityReports;
  final Map<String, String> communityNames;
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
  bool communityGames = false;
  String? selectedCommunity;
  bool? doubles;
  @override
  void didUpdateWidget(PlayerAnalyticsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (selectedCommunity != null &&
        !widget.communityReports.containsKey(selectedCommunity)) {
      selectedCommunity = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final useCommunity = communityGames && widget.communityReports.isNotEmpty;
    final useScorer = !useCommunity && scorer && widget.scorer != null;
    final communityLabels = {
      for (final entry in widget.communityReports.entries)
        for (final o in entry.value.observations)
          '${o.playerId}:${o.id}':
              widget.communityNames[entry.key] ?? entry.key,
    };
    final communityReport = StatisticsReport([
      for (final entry in widget.communityReports.entries)
        if (selectedCommunity == null || entry.key == selectedCommunity)
          ...entry.value.observations,
    ]);
    final report =
        (useCommunity
                ? communityReport
                : useScorer
                ? widget.scorer!
                : widget.tournaments)
            .filtered(period: period, doubleMatch: doubles);
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
        if (widget.scorer != null || widget.communityReports.isNotEmpty) ...[
          const SizedBox(height: 12),
          SportSectionNavigation<int>(
            label: 'Statistikbereich',
            selected: useCommunity
                ? 2
                : useScorer
                ? 0
                : 1,
            sections: [
              if (widget.scorer != null)
                const SportSection(
                  0,
                  'Meine Scorer-Spiele',
                  Icons.sports_score,
                ),
              const SportSection(
                1,
                'Turnierergebnisse',
                Icons.emoji_events_outlined,
              ),
              if (widget.communityReports.isNotEmpty)
                const SportSection(
                  2,
                  'Community-Spiele',
                  Icons.groups_outlined,
                ),
            ],
            onChanged: (value) => setState(() {
              communityGames = value == 2;
              scorer = value == 0;
              if (scorer) doubles = null;
            }),
          ),
        ],
        if (useCommunity)
          DropdownButtonFormField<String>(
            initialValue: selectedCommunity,
            isExpanded: true,
            itemHeight: null,
            isDense: false,
            decoration: const InputDecoration(labelText: 'Community filtern'),
            items: [
              const DropdownMenuItem<String>(
                value: null,
                child: Text('Alle Communities'),
              ),
              for (final id in widget.communityReports.keys)
                DropdownMenuItem(
                  value: id,
                  child: Text(widget.communityNames[id] ?? 'Community · $id'),
                ),
            ],
            onChanged: (id) => setState(() => selectedCommunity = id),
          ),
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
          useCommunity
              ? 'Deine zugeordneten Community-Begegnungen. Zeitraum, Community und Einzel/Doppel filtern alle Kennzahlen und Detailansichten.'
              : useScorer
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
          favoriteDouble: widget.favoriteDouble,
          community: widget.community || useCommunity,
          sessions: useScorer ? widget.heatmapSessions : null,
          period: period,
        ),
        StatisticsDashboard(
          report: report,
          title: 'Statistik · ${widget.name}',
        ),
        if (useCommunity) ...[
          Text(
            'Community-Begegnungen · ${report.observations.length}',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          if (report.observations.isEmpty)
            const Text('Keine eigenen Community-Spiele für diese Auswahl.'),
          for (final observation in report.observations.reversed)
            Card(
              child: ListTile(
                title: Text(observation.label),
                subtitle: Text(
                  '${communityLabels['${observation.playerId}:${observation.id}']} · ${observation.result == 'S'
                      ? 'Sieg'
                      : observation.result == 'N'
                      ? 'Niederlage'
                      : 'Unentschieden'} · ${observation.estimatedDate ? 'Spielzeit nicht erfasst' : observation.date.toLocal().toString().substring(0, 16)}',
                ),
              ),
            ),
        ],
        if (useScorer) ...?widget.footerBuilder?.call(period),
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
