import 'package:flutter/material.dart';
import '../../../shared/widgets/adaptive_content.dart';
import '../domain/tournament_player_statistics.dart';

class TournamentStatisticsView extends StatelessWidget {
  const TournamentStatisticsView({
    super.key,
    required this.rows,
    this.description =
        'Aus gespeicherten Turnierergebnissen dieser Community. Neue Ergebnisse erscheinen nach der Turniersynchronisierung. Korrekturen werden neu berechnet.',
  });
  final List<TournamentPlayerStatistics> rows;
  final String description;
  @override
  Widget build(BuildContext context) => AdaptiveContentList(
    children: [
      Text(
        'Spielerstatistiken',
        style: Theme.of(context).textTheme.headlineSmall,
      ),
      Text(description),
      const SizedBox(height: 16),
      if (rows.isEmpty)
        const Text('Noch keine abgeschlossenen Begegnungen gespeichert.'),
      for (final row in rows) TournamentStatisticsCard(row: row),
      const Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'Average, 180er und Checkoutquote berücksichtigen Spiele mit übertragenen Scorer-Aufnahmen. Reine Leg-/Set-Ergebnisse enthalten diese Daten nicht.',
        ),
      ),
    ],
  );
}

class TournamentStatisticsCard extends StatelessWidget {
  const TournamentStatisticsCard({super.key, required this.row});
  final TournamentPlayerStatistics row;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(row.name, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text('${row.tournaments.length} Turniere · ${row.matches} Spiele'),
          Text(
            '${row.wins} Siege · ${row.draws} Unentschieden · ${row.losses} Niederlagen',
          ),
          Text(
            'Legs: ${row.legsFor}:${row.legsAgainst} · Sets: ${row.setsFor}:${row.setsAgainst}',
          ),
          if (row.doublesMatches > 0) ...[
            const SizedBox(height: 8),
            Text(
              'Davon Doppel: ${row.doublesMatches} Spiele · ${row.doublesWins} Siege · ${row.doublesLosses} Niederlagen',
            ),
            Text(
              'Gemeinsame Doppel-Legs: ${row.doublesLegsFor}:${row.doublesLegsAgainst}',
            ),
          ],
          if (row.average != null)
            Text(
              'Average: ${row.average!.toStringAsFixed(2)} · 180er: ${row.scores180} · Checkout: ${row.checkoutPercent?.toStringAsFixed(1) ?? '–'} %',
            ),
        ],
      ),
    ),
  );
}
