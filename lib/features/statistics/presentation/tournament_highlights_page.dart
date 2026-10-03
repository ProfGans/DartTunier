import 'package:flutter/material.dart';
import '../../../shared/widgets/adaptive_content.dart';
import '../../tournaments/application/tournament_timing.dart';
import '../../tournaments/domain/tournament_models.dart';
import '../domain/match_scorer_summary.dart';
import '../../scorer/domain/scorer_highlight_rules.dart';

class TournamentHighlightsButton extends StatelessWidget {
  const TournamentHighlightsButton({super.key, required this.tournament});
  final CreatedTournament tournament;
  @override
  Widget build(BuildContext context) => TextButton.icon(
    icon: const Icon(Icons.auto_awesome),
    label: Text(
      tournament.finishedAt != null ||
              tournament.leagueMatch?.complete == true ||
              (tournament.stages.isNotEmpty &&
                  tournament.completedStageIndexes.contains(
                    tournament.stages.length - 1,
                  ))
          ? 'Turnier beendet · Statistik und Highlights'
          : 'Statistik und Highlights',
    ),
    onPressed: () => Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TournamentHighlightsPage(tournament: tournament),
      ),
    ),
  );
}

class TournamentHighlightsPage extends StatelessWidget {
  const TournamentHighlightsPage({super.key, required this.tournament});
  final CreatedTournament tournament;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Statistik und Highlights')),
    body: AdaptiveContentList(
      children: [
        Text(
          tournament.name,
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        TournamentHighlightsSection(tournament: tournament),
      ],
    ),
  );
}

/// Inline content shared by the results screen and the dedicated highlights page.
class TournamentHighlightsSection extends StatelessWidget {
  const TournamentHighlightsSection({
    super.key,
    required this.tournament,
    this.showPlayers = true,
  });
  final CreatedTournament tournament;
  final bool showPlayers;
  @override
  Widget build(BuildContext context) {
    final data = TournamentScorerHighlights(
      TournamentTiming.matches(tournament),
    );
    final rows = data.players;
    Widget card(String label, String value, String names) => Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.titleMedium),
            Text(value, style: Theme.of(context).textTheme.headlineSmall),
            Text(names),
          ],
        ),
      ),
    );
    Widget highlight(
      String label,
      num Function(ScorerHighlightPlayer) metric, {
      bool lowest = false,
      bool decimal = false,
      String unit = '',
    }) {
      final eligible = rows.where((p) => metric(p) > 0).toList()
        ..sort(
          (a, b) => lowest
              ? metric(a).compareTo(metric(b))
              : metric(b).compareTo(metric(a)),
        );
      if (eligible.isEmpty) return card(label, '–', 'Noch nicht erfasst');
      final best = metric(eligible.first);
      return card(
        label,
        '${decimal ? best.toStringAsFixed(2) : best.toString()}$unit',
        eligible.where((p) => metric(p) == best).map((p) => p.name).join(' · '),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${data.completed} abgeschlossene Spiele · ${data.recorded} mit Scorer-Statistik',
        ),
        const SizedBox(height: 16),
        AdaptiveTileLayout(
          children: [
            highlight(
              'Höchster Turnier-Average',
              (p) => p.average ?? 0,
              decimal: true,
            ),
            highlight('Höchstes Checkout', (p) => p.highestFinish),
            highlight(
              'Short Leg (bis 18 Darts)',
              (p) => p.bestLeg != null && p.bestLeg! <= highlightShortLegDarts
                  ? p.bestLeg!
                  : 0,
              lowest: true,
              unit: ' Darts',
            ),
            highlight('Meiste Maxima', (p) => p.maximumCount),
          ],
        ),
        const SizedBox(height: 16),
        const Text(
          'Maxima: 162, 165, 168, 171, 174, 177 und 180 Punkte. Short Legs: abgeschlossene Legs mit höchstens 18 Darts.',
        ),
        for (final p in rows.where(
          (p) => p.maxima.isNotEmpty || p.shortLegs.isNotEmpty,
        ))
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.name, style: Theme.of(context).textTheme.titleMedium),
                if (p.maxima.isNotEmpty)
                  Text('Maxima: ${highlightCountLabel(p.maxima)}'),
                if (p.shortLegs.isNotEmpty)
                  Text(
                    'Short Legs: ${highlightCountLabel(p.shortLegs, unit: ' Darts')}',
                  ),
              ],
            ),
          ),
        if (showPlayers)
          Text(
            'Scorer-Rangliste',
            style: Theme.of(context).textTheme.titleLarge,
          ),
        if (rows.isEmpty)
          const Text(
            'Noch keine Scorer-Aufnahmen übertragen. Manuelle Ergebnisse enthalten keine Average- oder Checkout-Daten.',
          ),
        if (showPlayers)
          for (final p in rows)
            card(
              p.name,
              'Average ${p.average!.toStringAsFixed(2)}',
              '${p.matches} gemessene Spiele · ${p.scores180} × 180 · höchstes Checkout ${p.highestFinish}',
            ),
        const Text(
          '3-Dart-Average aus allen erzielten Punkten und geworfenen Darts, nicht dem Mittel einzelner Averages. Doppel und Teams erhalten gemeinsame Werte. Highlights vergleichen die erfassten Spiele; unterschiedliche Startpunktzahlen und Distanzen sind möglich.',
        ),
      ],
    );
  }
}
