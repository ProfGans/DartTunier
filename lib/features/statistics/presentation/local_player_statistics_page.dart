import 'package:flutter/material.dart';

import '../../../shared/widgets/adaptive_content.dart';
import '../../rankings/domain/local_ranking.dart';
import '../domain/best_performance.dart';
import '../domain/local_statistics.dart';

class LocalPlayerStatisticsPage extends StatefulWidget {
  const LocalPlayerStatisticsPage({
    super.key,
    required this.name,
    required this.profileIds,
  });
  final String name;
  final Set<String> profileIds;
  @override
  State<LocalPlayerStatisticsPage> createState() => _LocalPlayerStatisticsPageState();
}

class _LocalPlayerStatisticsPageState extends State<LocalPlayerStatisticsPage> {
  late Future<(LocalPlayerStatistics, List<LocalRanking>)> _future = _load();

  Future<(LocalPlayerStatistics, List<LocalRanking>)> _load() async {
    const service = LocalStatisticsService();
    return (await service.forPlayers(widget.profileIds),
        await service.rankingsFor(widget.profileIds));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.name)),
    body: FutureBuilder<(LocalPlayerStatistics, List<LocalRanking>)>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return AdaptiveContentList(children: [
            const Text('Statistiken konnten nicht geladen werden.'),
            TextButton(onPressed: () => setState(() => _future = _load()), child: const Text('Erneut versuchen')),
          ]);
        }
        final data = snapshot.data;
        if (data == null) return const Center(child: CircularProgressIndicator());
        final stats = data.$1;
        final rankings = data.$2;
        final performanceCounts = {
          for (final type in BestPerformanceType.values)
            type: stats.bestPerformances.where((item) => item.type == type).length,
        };
        return AdaptiveContentList(children: [
          Text(widget.name, style: Theme.of(context).textTheme.headlineMedium),
          if (rankings.isNotEmpty)
            Text('Ist Mitglied in Rangliste${rankings.length == 1 ? '' : 'n'} ${rankings.map((r) => r.name).join(', ')}'),
          const SizedBox(height: 16),
          Text('Turniere & Spiele', style: Theme.of(context).textTheme.titleLarge),
          Wrap(spacing: 12, runSpacing: 12, children: [
            _StatCard(label: 'Turniere', value: '${stats.tournaments}'),
            _StatCard(label: 'Spiele', value: '${stats.matches}'),
            _StatCard(label: 'Siege', value: '${stats.wins}'),
            _StatCard(label: 'Niederlagen', value: '${stats.losses}'),
            _StatCard(label: 'Unentschieden', value: '${stats.draws}'),
            _StatCard(label: 'Siegquote', value: '${stats.matchWinRate.toStringAsFixed(1)} %'),
            _StatCard(label: 'Erwartete Siegchance (Elo)', value: stats.expectedWinChance == null ? '—' : '${stats.expectedWinChance!.toStringAsFixed(1)} %'),
          ]),
          const SizedBox(height: 20),
          Text('Legs & Sets', style: Theme.of(context).textTheme.titleLarge),
          Wrap(spacing: 12, runSpacing: 12, children: [
            _StatCard(label: 'Legs gewonnen / verloren', value: '${stats.legsWon} / ${stats.legsLost}'),
            _StatCard(label: 'Leg-Siegquote', value: '${stats.legWinRate.toStringAsFixed(1)} %'),
            _StatCard(label: 'Sets gewonnen / verloren', value: '${stats.setsWon} / ${stats.setsLost}'),
            _StatCard(label: 'Set-Siegquote', value: '${stats.setWinRate.toStringAsFixed(1)} %'),
          ]),
          const SizedBox(height: 20),
          Text('Bestleistungen', style: Theme.of(context).textTheme.titleLarge),
          Wrap(spacing: 12, runSpacing: 12, children: [
            _StatCard(label: '170+ Aufnahmen', value: '${performanceCounts[BestPerformanceType.score170]}'),
            _StatCard(label: '180+ Aufnahmen', value: '${performanceCounts[BestPerformanceType.score180]}'),
            _StatCard(label: 'High Finish (100+)', value: '${performanceCounts[BestPerformanceType.highFinish]}'),
            _StatCard(label: 'Shortlegs (≤18 Darts)', value: '${performanceCounts[BestPerformanceType.shortLeg]}'),
          ]),
          if (stats.bestPerformances.isNotEmpty)
            for (final item in stats.bestPerformances)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('${item.label}${item.value == null ? '' : ' ${item.value}'}'),
              ),
        ]);
      },
    ),
  );
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value});
  final String label, value;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 220,
    child: Card(child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(value, style: Theme.of(context).textTheme.headlineSmall),
        Text(label),
      ]),
    )),
  );
}
