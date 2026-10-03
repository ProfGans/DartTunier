import 'package:flutter/material.dart';
import '../../../../shared/widgets/adaptive_content.dart';
import '../../application/community_live_ranking.dart';

class CommunityLiveRankingView extends StatelessWidget {
  const CommunityLiveRankingView({super.key, required this.entries});
  final List<CommunityLiveRankingEntry> entries;
  @override
  Widget build(BuildContext context) {
    String signed(int value) => value > 0 ? '+$value' : '$value';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Live-Rangliste', style: Theme.of(context).textTheme.titleLarge),
        const Text(
          'Vergleich mit derselben Rangliste ohne Ergebnisse dieses Turniers. Lokal erfasste und vom Geräte-Scorer übernommene Ergebnisse aktualisieren die Anzeige. Gleich viel Elo bedeutet den gleichen Platz.',
        ),
        const SizedBox(height: 12),
        if (entries.isEmpty)
          const Text(
            'Noch keine gewerteten Spiele in dieser Rangliste und diesem Zeitraum.',
          ),
        AdaptiveTileLayout(
          children: [
            for (final row in entries)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Platz ${row.position} · ${row.entry.player.displayName}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        '${row.entry.rating} Elo · ${signed(row.eloChange)} Elo',
                      ),
                      Text(
                        row.positionChange == null
                            ? 'Neu in der Rangliste'
                            : row.positionChange! > 0
                            ? '↑ ${row.positionChange} Plätze gestiegen'
                            : row.positionChange! < 0
                            ? '↓ ${-row.positionChange!} Plätze gefallen'
                            : 'Platz unverändert',
                      ),
                      Text(
                        '${row.entry.matches} Spiele · ${row.entry.wins} Siege · ${row.entry.draws} Unentschieden · ${row.entry.losses} Niederlagen',
                      ),
                      if (row.participating)
                        const Text('Teilnehmer dieses Turniers'),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
