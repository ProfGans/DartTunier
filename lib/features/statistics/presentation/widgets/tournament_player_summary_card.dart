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
    summary: '${row.wins} Siege · ${row.matches} Spiele',
    icon: Icons.person_outline,
    children: [
      Text(
        '${row.wins} Siege · ${row.draws} Unentschieden · ${row.losses} Niederlagen',
      ),
      Text(
        'Legs: ${row.legsFor}:${row.legsAgainst} · Sets: ${row.setsFor}:${row.setsAgainst}',
      ),
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
