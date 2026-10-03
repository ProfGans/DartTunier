import 'package:flutter/material.dart';
import '../../../shared/widgets/adaptive_content.dart';
import '../../communities/domain/community_statistics.dart';
import '../../communities/presentation/community_player_statistics_page.dart';
import '../domain/community_trends.dart';

class CommunityTrendsPage extends StatelessWidget {
  const CommunityTrendsPage({
    super.key,
    required this.communityName,
    required this.data,
    this.now,
  });
  final String communityName;
  final CommunityStatistics data;
  final DateTime? now;
  static const titles = {
    CommunityTrendKind.rising: 'Spieler im Aufwind',
    CommunityTrendKind.practice: 'Ab ans Practice Board',
    CommunityTrendKind.stable: 'Stabile Form',
    CommunityTrendKind.insufficient: 'Noch zu wenig Vergleichsdaten',
  };
  @override
  Widget build(BuildContext context) {
    final trends = CommunityTrends(data, now: now);
    String date(DateTime d) => '${d.day}.${d.month}.${d.year}';
    String value(double? n) => n?.toStringAsFixed(1) ?? '–';
    final previousEnd = DateTime(
      trends.previousPeriod.endExclusive.year,
      trends.previousPeriod.endExclusive.month,
      trends.previousPeriod.endExclusive.day - 1,
    );
    final recentEnd = DateTime(
      trends.recentPeriod.endExclusive.year,
      trends.recentPeriod.endExclusive.month,
      trends.recentPeriod.endExclusive.day - 1,
    );
    return Scaffold(
      appBar: AppBar(title: Text('Trends · $communityName')),
      body: AdaptiveContentList(
        children: [
          Text(
            'Die letzten drei Monate',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          Text(
            'Aktuell: ${date(trends.recentPeriod.start)} – ${date(recentEnd)}',
          ),
          Text(
            'Vergleich: ${date(trends.previousPeriod.start)} – ${date(previousEnd)}',
          ),
          const SizedBox(height: 12),
          const Text(
            'Einordnung nach Ergebnisquote: Siege zählen voll, Unentschieden halb. Ab ±15 Prozentpunkten und mindestens 5 Spielen je Zeitraum entsteht ein Trend. Gegnerstärke und Spielformat können die Quote beeinflussen; dies ist keine Elo-Wertung.',
          ),
          const Text(
            'Nur gespeicherte Ergebnisse dieser Community. Spiele ohne erfasste Spielzeit fehlen im Zeitvergleich; bei Ligaspielen zählt das Turnierdatum. Scorer-Werte beziehen sich nur auf erfasste Aufnahmen und bestimmen die Kategorie nicht.',
          ),
          for (final kind in CommunityTrendKind.values) ...[
            const SizedBox(height: 24),
            Text(titles[kind]!, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            if (!trends.players.any((p) => p.kind == kind))
              const Text('Aktuell keine Spieler in dieser Kategorie.'),
            AdaptiveTileLayout(
              children: [
                for (final row in trends.players.where((p) => p.kind == kind))
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            row.player.name,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          Text(
                            '${row.previous?.matches ?? 0} → ${row.recent?.matches ?? 0} Spiele (vorher → aktuell)',
                          ),
                          Text(
                            'Ergebnisquote: ${value(CommunityPlayerTrend.rate(row.previous))} % → ${value(CommunityPlayerTrend.rate(row.recent))} %',
                          ),
                          if (row.change != null)
                            Text(
                              '${row.change! > 0 ? '+' : ''}${value(row.change)} Prozentpunkte',
                            ),
                          if (row.previous?.average != null ||
                              row.recent?.average != null)
                            Text(
                              '3-Dart-Average: ${value(row.previous?.average)} → ${value(row.recent?.average)}',
                            ),
                          if (kind == CommunityTrendKind.insufficient)
                            const Text(
                              'Für eine Einordnung sind mindestens 5 Spiele in jedem der beiden Zeiträume erforderlich.',
                            ),
                          TextButton.icon(
                            icon: const Icon(Icons.person_outline),
                            label: const Text('Spielerstatistik öffnen'),
                            onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => CommunityPlayerStatisticsPage(
                                  communityName: communityName,
                                  data: data,
                                  player: row.player,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
