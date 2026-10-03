import 'package:flutter/material.dart';
import '../../../shared/widgets/adaptive_content.dart';
import '../../statistics/domain/statistics_period.dart';
import '../../statistics/domain/tournament_player_statistics.dart';
import '../../statistics/presentation/statistics_period_filter.dart';
import '../../statistics/presentation/tournament_statistics_view.dart';
import '../domain/community_statistics.dart';

class CommunityPlayerStatisticsPage extends StatefulWidget {
  const CommunityPlayerStatisticsPage({
    super.key,
    required this.communityName,
    required this.data,
    required this.player,
  });
  final String communityName;
  final CommunityStatistics data;
  final CommunityStatisticsPlayer player;
  @override
  State<CommunityPlayerStatisticsPage> createState() => _PlayerState();
}

class _PlayerState extends State<CommunityPlayerStatisticsPage> {
  StatisticsPeriod? _period;
  String _periodLabel = 'Gesamt';
  @override
  Widget build(BuildContext context) {
    final row = widget.data
        .rows(period: _period)
        .where((r) => r.id == widget.player.id)
        .firstOrNull;
    final results = [
      for (final tournament in widget.data.tournaments)
        for (final stats in widget.data.rows(
          period: _period,
          source: [tournament],
        ))
          if (stats.id == widget.player.id)
            (tournament: tournament, stats: stats),
    ]..sort((a, b) => b.tournament.createdAt.compareTo(a.tournament.createdAt));
    return Scaffold(
      appBar: AppBar(title: const Text('Spielerstatistik')),
      body: AdaptiveContentList(
        children: [
          Text(
            widget.player.name,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          Text(widget.communityName),
          StatisticsPeriodFilter(
            selected: _periodLabel,
            period: _period,
            onChanged: (label, period) => setState(() {
              _periodLabel = label;
              _period = period;
            }),
          ),
          if (row == null)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Noch keine abgeschlossenen Begegnungen im gewählten Zeitraum gespeichert.',
              ),
            ),
          TournamentStatisticsCard(
            playerName: widget.player.name,
            row:
                row ??
                TournamentPlayerStatistics(
                  widget.player.id,
                  widget.player.name,
                ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'Nur Ergebnisse dieser Community. Average, 180er und Checkoutquote sind verfügbar, wenn Scorer-Aufnahmen übertragen wurden. Ranglisten-Resets ändern diese Statistiken nicht.',
            ),
          ),
          if (results.isNotEmpty) ...[
            Text('Turniere', style: Theme.of(context).textTheme.titleLarge),
            for (final result in results)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        result.tournament.name,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        '${result.stats.matches} Spiele · ${result.stats.wins} Siege · ${result.stats.draws} Unentschieden · ${result.stats.losses} Niederlagen',
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
