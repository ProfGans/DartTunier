import 'package:flutter/material.dart';
import '../../domain/tournament_models.dart';

class TournamentSummaryCard extends StatelessWidget {
  const TournamentSummaryCard({
    super.key,
    required this.tournament,
    required this.onOpen,
    required this.onDelete,
  });
  final CreatedTournament tournament;
  final VoidCallback onOpen, onDelete;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final last = tournament.runStages.length - 1;
    final complete =
        tournament.finishedAt != null ||
        (last >= 0 && tournament.completedStageIndexes.contains(last));
    final status = complete
        ? 'Abgeschlossen'
        : tournament.startedAt != null
        ? 'Läuft'
        : 'Bereit';
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      tournament.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'Turnieraktionen',
                    onSelected: (_) => onDelete(),
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: 'delete',
                        child: Text('Turnier loeschen'),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (tournament.communityId != null) ...[
                Row(
                  children: [
                    Icon(
                      Icons.groups_outlined,
                      size: 20,
                      color: scheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Community-Turnier',
                        style: Theme.of(
                          context,
                        ).textTheme.labelLarge?.copyWith(color: scheme.primary),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
              Text(
                tournament.leagueMatch != null
                    ? 'Ligaspiel · ${tournament.leagueMatch!.homePoints}:${tournament.leagueMatch!.awayPoints} Mannschaftspunkte'
                    : '${tournament.players.length} Spieler · ${tournament.stages.length} Etappen',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '$status · ${complete ? 'Ergebnisse ansehen' : 'Turnier öffnen'}',
                      style: TextStyle(
                        color: scheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Icon(Icons.arrow_forward, color: scheme.primary),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
