import 'package:flutter/material.dart';
import '../../../../../shared/widgets/adaptive_content.dart';
import '../../../../statistics/domain/tournament_player_statistics.dart';
import '../../../../statistics/presentation/tournament_highlights_page.dart';
import '../../../../statistics/presentation/tournament_statistics_view.dart';
import '../../../domain/tournament_models.dart';

class TournamentResultsStatistics extends StatelessWidget {
  const TournamentResultsStatistics({super.key, required this.tournament});
  final CreatedTournament tournament;

  @override
  Widget build(BuildContext context) {
    final players = const TournamentStatisticsCalculator().calculate([
      tournament,
    ]);
    final heading = Theme.of(
      context,
    ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Highlights', style: heading),
        const SizedBox(height: 12),
        TournamentHighlightsSection(tournament: tournament, showPlayers: false),
        const SizedBox(height: 24),
        Text('Spielerstatistiken', style: heading),
        const SizedBox(height: 12),
        if (players.isEmpty)
          const Text('Noch keine abgeschlossenen Begegnungen gespeichert.'),
        AdaptiveTileLayout(
          children: [
            for (final player in players) TournamentStatisticsCard(row: player),
          ],
        ),
        const Text(
          'Average, 180er und Checkoutquote stammen aus übertragenen Scorer-Aufnahmen. Bei manuell erfassten Ergebnissen werden nur die verfügbaren Spiel-, Leg- und Set-Werte angezeigt.',
        ),
      ],
    );
  }
}
