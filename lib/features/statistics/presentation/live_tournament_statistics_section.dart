import 'package:flutter/material.dart';
import '../../tournaments/domain/tournament_models.dart';
import '../domain/tournament_player_statistics.dart';
import 'tournament_highlights_page.dart';
import 'tournament_statistics_view.dart';

/// Rebuilt from current results so edits and removed results are reflected.
class LiveTournamentStatisticsSection extends StatelessWidget {
  const LiveTournamentStatisticsSection({super.key, required this.tournament});
  final CreatedTournament tournament;

  @override
  Widget build(BuildContext context) {
    final rows = const TournamentStatisticsCalculator().calculate([tournament]);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1000),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Turnierstatistik', style: Theme.of(context).textTheme.headlineSmall),
            const Text('Aktueller Stand über alle Etappen. Abgeschlossene Spiele und Ergebniskorrekturen werden berücksichtigt.'),
            const SizedBox(height: 16),
            TournamentHighlightsSection(tournament: tournament, showPlayers: false),
            const SizedBox(height: 16),
            Text('Spielerstatistiken', style: Theme.of(context).textTheme.titleLarge),
            if (rows.isEmpty) const Text('Noch keine abgeschlossenen Spiele mit menschlichen Teilnehmern.'),
            for (final row in rows) TournamentStatisticsCard(row: row),
            const Text('Average, 180er und Checkoutquote benötigen übertragene Scorer-Aufnahmen. Bots erhalten keine Spielerstatistiken.'),
          ],
        ),
      ),
    );
  }
}
