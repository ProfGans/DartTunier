import 'package:flutter/material.dart';
import '../../data/scorer_heatmap_repository.dart';
import '../../domain/scorer_heatmap_summary.dart';
import '../../domain/statistics_period.dart';
import 'scorer_heatmap_page.dart';
import 'scorer_heatmap_view.dart';

class CockpitHeatmapSection extends StatefulWidget {
  const CockpitHeatmapSection({
    super.key,
    required this.subject,
    this.sessions,
    this.period,
    this.community = false,
  });
  final String subject;
  final List<ScorerHeatmapSession>? sessions;
  final StatisticsPeriod? period;
  final bool community;
  @override
  State<CockpitHeatmapSection> createState() => _SectionState();
}

class _SectionState extends State<CockpitHeatmapSection>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  late Future<List<ScorerHeatmapSession>> future = _load();
  bool estimates = true, checkoutOnly = false;
  Future<List<ScorerHeatmapSession>> _load() async => widget.sessions ?? [];

  @override
  void didUpdateWidget(CockpitHeatmapSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sessions != widget.sessions ||
        oldWidget.community != widget.community) {
      future = _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Heatmap · Trefferbild',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            Text(widget.subject),
            const Text(
              'Wo landen deine Darts? Trefferdichte, häufige Felder und Streuung im gewählten Zeitraum.',
            ),
            FutureBuilder<List<ScorerHeatmapSession>>(
              future: future,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Column(
                    children: [
                      const Text(
                        'Trefferpositionen konnten nicht geladen werden.',
                      ),
                      TextButton(
                        onPressed: () => setState(() => future = _load()),
                        child: const Text('Erneut versuchen'),
                      ),
                    ],
                  );
                }
                if (!snapshot.hasData) return const LinearProgressIndicator();
                final sessions = snapshot.data!
                    .where(
                      (s) =>
                          widget.period == null ||
                          widget.period!.contains(s.date),
                    )
                    .toList();
                final hits = [for (final s in sessions) ...s.hits]
                    .where(
                      (h) =>
                          (estimates || !h.location.estimated) &&
                          (!checkoutOnly || h.checkoutAttempt == true),
                    )
                    .toList();
                final summary = ScorerHeatmapSummary(hits);
                final controls = Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Schätzungen einschließen'),
                      value: estimates,
                      onChanged: (v) => setState(() => estimates = v),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Nur Checkoutversuche'),
                      value: checkoutOnly,
                      onChanged: (v) => setState(() => checkoutOnly = v),
                    ),
                    Text(
                      '${hits.length} ${hits.length == 1 ? 'lokalisierter Dart' : 'lokalisierte Darts'}',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text(
                      'Spiele mit Treffern: ${sessions.where((s) => s.hits.any(hits.contains)).length}',
                    ),
                    if (hits.isNotEmpty) ...[
                      Text(
                        'Streuung: ${summary.spread.toStringAsFixed(1)} mm (RMS)',
                      ),
                      Text(
                        'Schätzungen: ${hits.where((h) => h.location.estimated).length} · Korrigiert: ${hits.where((h) => h.location.corrected).length}',
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Häufigste Felder',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      for (final field in summary.ranked.take(5))
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Text(
                            '${field.key}: ${field.value} Treffer · ${(100 * field.value / hits.length).toStringAsFixed(1)} %',
                          ),
                        ),
                      const Text(
                        'Streuung beschreibt die Verteilung der Einschläge, nicht die Abweichung vom anvisierten Ziel.',
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        icon: const Icon(Icons.open_in_full),
                        label: const Text('Heatmap im Detail'),
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => ScorerHeatmapPage(
                              sessions: [
                                for (final s in sessions)
                                  ScorerHeatmapSession(
                                    id: s.id,
                                    date: s.date,
                                    names: s.names,
                                    complete: s.complete,
                                    hits: s.hits.where(hits.contains).toList(),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                );
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (hits.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          widget.community
                              ? 'Für diese Community liegen keine freigegebenen Trefferpositionen vor. Private lokale Heatmaps werden hier nicht angezeigt.'
                              : 'Keine zugeordneten Trefferpositionen für diese Auswahl. Autoscoring-Treffer erscheinen hier, sobald sie mit deinem Profil gespeichert wurden. Alte Spiele und manuelle Punktsummen liefern keine Positionen.',
                        ),
                      ),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        if (hits.isEmpty) return controls;
                        final board = Column(
                          children: [
                            ScorerHeatmapView(hits: hits),
                            const Text(
                              'Rot = hohe, Gelb = mittlere, Blau = geringe Dichte. Die Skala gilt für diese Auswahl. Ringe: Bernstein = Schätzung, Türkis = Korrektur.',
                            ),
                          ],
                        );
                        if (constraints.maxWidth >= 820 &&
                            MediaQuery.textScalerOf(context).scale(16) <= 24) {
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: board),
                              const SizedBox(width: 24),
                              Expanded(child: controls),
                            ],
                          );
                        }
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            board,
                            const SizedBox(height: 12),
                            controls,
                          ],
                        );
                      },
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
