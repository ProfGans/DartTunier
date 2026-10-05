import '../../domain/scorer_heatmap_summary.dart';
import 'package:flutter/material.dart';
import '../../../../shared/widgets/adaptive_content.dart';
import '../../data/scorer_heatmap_repository.dart';
import 'scorer_heatmap_view.dart';

class ScorerHeatmapPage extends StatefulWidget {
  const ScorerHeatmapPage({super.key, this.sessions, this.initialPlayer});
  final List<ScorerHeatmapSession>? sessions;
  final String? initialPlayer;
  @override
  State<ScorerHeatmapPage> createState() => _HeatmapState();
}

class _HeatmapState extends State<ScorerHeatmapPage> {
  late Future<List<ScorerHeatmapSession>> future = widget.sessions == null
      ? ScorerHeatmapRepository().load()
      : Future.value(widget.sessions);
  late String? player = widget.initialPlayer;
  String? session;
  int? leg;
  int days = 0;
  bool estimates = true, checkoutOnly = false;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Autoscoring · Heatmap')),
    body: FutureBuilder<List<ScorerHeatmapSession>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return AdaptiveContentList(
            children: [
              const Text('Heatmaps konnten nicht geladen werden.'),
              TextButton(
                onPressed: () =>
                    setState(() => future = ScorerHeatmapRepository().load()),
                child: const Text('Erneut versuchen'),
              ),
            ],
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final sessions = snapshot.data!;
        final names = {
          for (final s in sessions)
            for (final h in s.hits) h.thrower,
        }.toList()..sort();
        if (player != null && !names.contains(player)) names.add(player!);
        final selected = sessions
            .where(
              (s) =>
                  (session == null || s.id == session) &&
                  (days == 0 ||
                      s.date.isAfter(
                        DateTime.now().subtract(Duration(days: days)),
                      )),
            )
            .toList();
        final all = [for (final s in selected) ...s.hits];
        final legs = all.map((h) => h.leg).toSet().toList()..sort();
        final hits = all
            .where(
              (h) =>
                  (player == null || h.thrower == player) &&
                  (leg == null || h.leg == leg) &&
                  (estimates || !h.location.estimated) &&
                  (!checkoutOnly || h.checkoutAttempt == true),
            )
            .toList();
        final summary = ScorerHeatmapSummary(hits);
        final ranked = summary.ranked;
        final x = summary.x, y = summary.y, spread = summary.spread;
        String percent(int n) => hits.isEmpty
            ? '—'
            : '${(n * 100 / hits.length).toStringAsFixed(1)} %';
        return AdaptiveContentList(
          children: [
            const Text(
              'Gespeicherte Einschlagpositionen auf diesem Gerät. Alte Spiele ohne Positionsdaten, Bots und manuell eingegebene Summen sind nicht enthalten. Überwürfe bleiben als tatsächlich geworfene Treffer sichtbar.',
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: names.contains(player) ? player : null,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Spieler / Teammitglied',
              ),
              items: [
                const DropdownMenuItem<String>(
                  value: null,
                  child: Text('Alle Spieler'),
                ),
                for (final n in names)
                  DropdownMenuItem(value: n, child: Text(n)),
              ],
              onChanged: (v) => setState(() => player = v),
            ),
            DropdownButtonFormField<String>(
              initialValue: session,
              isExpanded: true,
              itemHeight: null,
              decoration: const InputDecoration(labelText: 'Spiel'),
              items: [
                const DropdownMenuItem<String>(
                  value: null,
                  child: Text('Alle Spiele'),
                ),
                for (final s in sessions)
                  DropdownMenuItem(
                    value: s.id,
                    child: Text(
                      '${s.date.toLocal().day}.${s.date.toLocal().month}.${s.date.toLocal().year} · ${s.names.join(' – ')}${s.complete ? '' : ' · laufend'}',
                    ),
                  ),
              ],
              onChanged: (v) => setState(() {
                session = v;
                leg = null;
              }),
            ),
            DropdownButtonFormField<int>(
              initialValue: days,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Zeitraum'),
              items: [
                for (final n in [0, 7, 30, 90])
                  DropdownMenuItem(
                    value: n,
                    child: Text(
                      n == 0 ? 'Gesamter Zeitraum' : 'Letzte $n Tage',
                    ),
                  ),
              ],
              onChanged: (v) => setState(() {
                days = v!;
                leg = null;
              }),
            ),
            if (session != null)
              DropdownButtonFormField<int>(
                key: ValueKey('$session-$days-$leg'),
                initialValue: leg,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Leg'),
                items: [
                  const DropdownMenuItem<int>(
                    value: null,
                    child: Text('Alle Legs'),
                  ),
                  for (final n in legs)
                    DropdownMenuItem(value: n, child: Text('Leg ${n + 1}')),
                ],
                onChanged: (v) => setState(() => leg = v),
              ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Schätzungen einschließen'),
              value: estimates,
              onChanged: (v) => setState(() => estimates = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Nur Checkoutversuche'),
              subtitle: const Text(
                'Aus dem Restscore abgeleitete oder manuell korrigierte Doppelversuche.',
              ),
              value: checkoutOnly,
              onChanged: (v) => setState(() => checkoutOnly = v),
            ),
            if (hits.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Keine gespeicherten Trefferpositionen für diese Auswahl.',
                ),
              ),
            ScorerHeatmapView(hits: hits),
            const Text(
              'Rot = hohe, Gelb = mittlere, Blau = geringe Trefferdichte innerhalb dieser Auswahl. Die Farbskala wird je Auswahl angepasst. Bernsteinfarbene Ringe markieren Schätzungen, türkise Ringe Korrekturen.',
            ),
            const SizedBox(height: 16),
            Text(
              'Auswertung · ${hits.length} lokalisierte Darts',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Text(
              '${selected.where((s) => s.hits.any((h) => hits.contains(h))).length} Spiele mit Treffern in dieser Auswahl',
            ),
            Text(
              'Schätzungen: ${hits.where((h) => h.location.estimated).length} · Korrigiert: ${hits.where((h) => h.location.corrected).length}',
            ),
            Text(
              'T20-Anteil: ${percent(hits.where((h) => h.label == 'T20').length)}',
            ),
            Text(
              'Doppel / Bull: ${percent(hits.where((h) => h.label.startsWith('D') || h.label == 'BULL').length)} · Triple: ${percent(hits.where((h) => h.label.startsWith('T')).length)}',
            ),
            if (hits.isNotEmpty)
              Text(
                'Schwerpunkt: ${x.toStringAsFixed(1)} mm rechts, ${(-y).toStringAsFixed(1)} mm oben vom Bull. Streuung um diesen Schwerpunkt: ${spread.toStringAsFixed(1)} mm (RMS).',
              ),
            const Text(
              'Streuung beschreibt die Verteilung der Einschläge, nicht die Abweichung vom anvisierten Ziel. Feldanteile beziehen sich nur auf lokalisierte Darts und sind keine Checkoutquote.',
            ),
            const SizedBox(height: 16),
            Text(
              'Getroffene Felder',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            for (final e in ranked)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(e.key),
                subtitle: Text('${e.value} Treffer · ${percent(e.value)}'),
              ),
          ],
        );
      },
    ),
  );
}
