import 'package:flutter/material.dart';
import '../../tournaments/data/tournament_storage.dart';
import '../../../shared/widgets/adaptive_content.dart';
import '../domain/analytics/statistics_report.dart';
import 'analytics/player_analytics_page.dart';

class LocalPlayerStatisticsPage extends StatefulWidget {
  const LocalPlayerStatisticsPage({
    super.key,
    required this.name,
    required this.profileIds,
  });
  final String name;
  final Set<String> profileIds;
  @override
  State<LocalPlayerStatisticsPage> createState() => _LocalState();
}

class _LocalState extends State<LocalPlayerStatisticsPage> {
  late Future<StatisticsReport> future = load();
  Future<StatisticsReport> load() async => const StatisticsAnalytics()
      .tournaments(await TournamentStorage().loadTournaments())
      .filtered(players: widget.profileIds);
  @override
  Widget build(BuildContext context) => FutureBuilder<StatisticsReport>(
    future: future,
    builder: (context, snapshot) {
      if (snapshot.hasData) {
        return PlayerAnalyticsPage(
          name: widget.name,
          tournaments: snapshot.data!,
        );
      }
      return Scaffold(
        appBar: AppBar(title: Text(widget.name)),
        body: snapshot.hasError
            ? AdaptiveContentList(
                children: [
                  const Text(
                    'Spielerstatistiken konnten nicht geladen werden.',
                  ),
                  TextButton(
                    onPressed: () => setState(() => future = load()),
                    child: const Text('Erneut versuchen'),
                  ),
                ],
              )
            : const Center(child: CircularProgressIndicator()),
      );
    },
  );
}
