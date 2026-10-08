import 'package:flutter/material.dart';
import '../../../../shared/widgets/sport_settings_section.dart';
import '../../domain/tournament_player_statistics.dart';

class TournamentPlayerSummaryCard extends StatelessWidget {
  const TournamentPlayerSummaryCard({super.key, required this.row});
  final TournamentPlayerStatistics row;
  @override
  Widget build(BuildContext context) => SportSettingsSection(
    key: ValueKey(row.id),
    title: row.name,
    summary:
        '${row.wins} Siege · ${row.matches} Spiele · Avg ${row.average?.toStringAsFixed(2) ?? '–'}',
    icon: Icons.person_outline,
    children: [
      Text(
        '${row.wins} Siege · ${row.draws} Unentschieden · ${row.losses} Niederlagen',
      ),
      Text(
        'Legs: ${row.legsFor}:${row.legsAgainst} · Sets: ${row.setsFor}:${row.setsAgainst}',
      ),
      if (row.average != null)
        Text(
          'Average: ${row.average!.toStringAsFixed(2)} · 180er: ${row.scores180} · Checkout: ${row.checkoutPercent?.toStringAsFixed(1) ?? '–'} %',
        )
      else
        const Text('Für Average und Checkout fehlen Scorer-Aufnahmen.'),
      if (row.doublesMatches > 0) ...[
        Text(
          'Davon Doppel: ${row.doublesMatches} Spiele · ${row.doublesWins} Siege · ${row.doublesLosses} Niederlagen',
        ),
        Text(
          'Gemeinsame Doppel-Legs: ${row.doublesLegsFor}:${row.doublesLegsAgainst}',
        ),
      ],
    ],
  );
}
