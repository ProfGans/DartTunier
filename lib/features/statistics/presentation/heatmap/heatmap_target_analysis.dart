import 'package:flutter/material.dart';
import '../../../scorer/domain/scorer_hit.dart';
import '../../../scorer/domain/preferred_checkouts.dart';
import '../../data/scorer_heatmap_repository.dart';
import '../../domain/heatmap_analysis.dart';
import '../../domain/scorer_heatmap_summary.dart';
import 'scorer_heatmap_view.dart';

class HeatmapTargetAnalysis extends StatelessWidget {
  const HeatmapTargetAnalysis({
    super.key,
    required this.hits,
    required this.sessions,
    this.favoriteDouble = '',
    required this.compare,
  });
  final List<ScorerHit> hits;
  final List<ScorerHeatmapSession> sessions;
  final String favoriteDouble;
  final bool compare;
  @override
  Widget build(BuildContext context) {
    final targets = HeatmapAnalysis.targets(hits);
    final now = DateTime.now();
    final recentStart = now.subtract(const Duration(days: 28));
    final previousStart = now.subtract(const Duration(days: 56));
    final current = <ScorerHit>[], previous = <ScorerHit>[];
    for (final session in sessions) {
      for (final hit in session.hits.where(hits.contains)) {
        final date = hit.thrownAt ?? session.date;
        if (date.isAfter(now)) continue;
        if (!date.isBefore(recentStart)) {
          current.add(hit);
        } else if (!date.isBefore(previousStart)) {
          previous.add(hit);
        }
      }
    }
    Widget period(String label, List<ScorerHit> points) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label, style: Theme.of(context).textTheme.titleMedium),
        Text(
          '${points.length} lokalisierte Darts · Streuung ${points.isEmpty ? '—' : '${ScorerHeatmapSummary(points).spread.toStringAsFixed(1)} mm'}',
        ),
        if (points.isNotEmpty)
          ScorerHeatmapView(hits: points)
        else
          const Text('Keine Treffer im Zeitraum.'),
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (compare) ...[
          Text(
            'Entwicklung · 28 Tage vergleichen',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const Text(
            'Letzte 28 Tage gegen die 28 Tage davor, innerhalb der aktuellen Filter. Ohne Wurfzeit gilt das Sitzungsdatum. Farben werden pro Auswahl skaliert; Trefferzahlen und Streuung mit vergleichen.',
          ),
          LayoutBuilder(
            builder: (context, c) =>
                c.maxWidth >= 800 &&
                    MediaQuery.textScalerOf(context).scale(16) < 25
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: period('Vorherige 28 Tage', previous)),
                      const SizedBox(width: 16),
                      Expanded(child: period('Letzte 28 Tage', current)),
                    ],
                  )
                : Column(
                    children: [
                      period('Vorherige 28 Tage', previous),
                      const SizedBox(height: 16),
                      period('Letzte 28 Tage', current),
                    ],
                  ),
          ),
        ],
        const SizedBox(height: 16),
        Text(
          'Zielanalyse & Training',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        if (favoriteDouble.isNotEmpty)
          Text('Dein Lieblingsdoppel: $favoriteDouble'),
        Text(
          '${hits.where((h) => h.targetLabel != null).length} Treffer mit erfasstem Ziel · ${hits.where((h) => h.targetLabel == null).length} ohne Zielangabe',
        ),
        if (targets.isEmpty)
          const Text(
            'Noch keine anvisierten Ziele erfasst. Wähle im Scorer vor dem Wurf ein Ziel; alte Treffer werden nicht nachträglich als Zielversuche ausgelegt.',
          ),
        const Text(
          'Anteile beziehen sich nur auf lokalisierte Würfe mit ausdrücklich erfasstem Ziel. Nicht lokalisierte Fehlwürfe fehlen; dies ist keine vollständige Checkoutquote.',
        ),
        for (final target in targets)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    target.target ==
                            PreferredCheckouts.normalizeDouble(favoriteDouble)
                        ? '${target.target} · Lieblingsdoppel'
                        : target.target,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Text(
                    '${target.successes}/${target.hits.length} im Zielsegment · ${target.percent.toStringAsFixed(1)} %',
                  ),
                  Text(
                    'Nachbarfelder: ${target.neighborHits} · Gruppierung: ${ScorerHeatmapSummary(target.hits).spread.toStringAsFixed(1)} mm (RMS)',
                  ),
                  if (target.meanTargetDistance != null)
                    Text(
                      'Mittlerer Abstand zur Segmentmitte: ${target.meanTargetDistance!.toStringAsFixed(1)} mm',
                    ),
                  const Text(
                    'Segmentmitten-Abstand ist eine geometrische Orientierung. Gruppierung und Zielgenauigkeit sind unterschiedliche Werte.',
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
