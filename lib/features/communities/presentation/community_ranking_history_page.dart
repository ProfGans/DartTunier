import 'package:flutter/material.dart';
import '../../../shared/widgets/adaptive_content.dart';
import '../domain/community_elo.dart';
import '../domain/community_elo_records.dart';
import 'widgets/community_elo_chart.dart';

class CommunityRankingHistoryPage extends StatelessWidget {
  const CommunityRankingHistoryPage({
    super.key,
    required this.entry,
    required this.history,
    required this.currentYearOnly,
  });
  final CommunityEloEntry entry;
  final List<CommunityEloHistoryItem> history;
  final bool currentYearOnly;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(entry.player.displayName)),
    body: AdaptiveContentList(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          '${currentYearOnly ? 'Jahreswertung' : 'Gesamtwertung'} · Aktuell ${entry.rating} Elo',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        CommunityEloChart(history: history),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bestwerte & Bilanz',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text('Höchster Elo-Wert: ${CommunityEloRecords(history).peak}'),
                Text(
                  'Größter Elo-Gewinn pro Begegnung: ${history.isEmpty ? '—' : '+${CommunityEloRecords(history).largestGain}'}',
                ),
                Text(
                  '${entry.matches} Spiele · ${entry.wins} Siege · ${entry.draws} Unentschieden · ${entry.losses} Niederlagen',
                ),
                Text(
                  'Siegquote: ${entry.matches == 0 ? '—' : '${(100 * entry.wins / entry.matches).toStringAsFixed(1)} %'}',
                ),
                const SizedBox(height: 8),
                const Text(
                  'Aus ranglistenrelevanten Community-Spielen im ausgewählten Zeitraum. Startwert: 1000 Elo.',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text('Begegnungen', style: Theme.of(context).textTheme.titleLarge),
        if (history.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('Noch keine ranglistenrelevanten Begegnungen.'),
            ),
          )
        else
          ...history.reversed.map(
            (item) => Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${item.opponentName} · ${item.score}'),
                    Text(
                      '${item.tournamentName} · ${item.playedAt.day.toString().padLeft(2, '0')}.${item.playedAt.month.toString().padLeft(2, '0')}.${item.playedAt.year}',
                    ),
                    Text(
                      '${item.delta >= 0 ? '+' : ''}${item.delta} · ${item.ratingAfter} Elo',
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    ),
  );
}
