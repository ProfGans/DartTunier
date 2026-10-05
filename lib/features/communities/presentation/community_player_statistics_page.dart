import 'package:flutter/material.dart';
import '../../statistics/domain/analytics/statistics_report.dart';
import '../../statistics/presentation/analytics/player_analytics_page.dart';
import '../domain/community_statistics.dart';

class CommunityPlayerStatisticsPage extends StatelessWidget {
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
  Widget build(BuildContext context) => PlayerAnalyticsPage(
    community: true,
    name: '${player.name} · $communityName',
    tournaments: const StatisticsAnalytics()
        .tournaments(data.tournaments, aliases: data.aliases)
        .filtered(players: {player.id}),
  );
}
