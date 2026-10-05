import '../../../shared/widgets/sport_menu.dart';
import 'community_analytics_page.dart';
import 'package:flutter/material.dart';
import '../domain/community_statistics.dart';
import 'community_statistics_players_page.dart';
import '../../community_highlights/presentation/community_highlights_page.dart';
import '../../community_trends/presentation/community_trends_page.dart';

class CommunityStatisticsMenu extends StatelessWidget {
  const CommunityStatisticsMenu({
    super.key,
    required this.communityName,
    required this.data,
  });
  final String communityName;
  final CommunityStatistics data;
  @override
  Widget build(BuildContext context) => CommunityAnalyticsPage(
    embedded: true,
    name: communityName,
    data: data,
    actions: [
      SportMenuGroup(
        title: 'Auswertungen',
        actions: [
          SportMenuAction(
            icon: Icons.person_outline,
            label: 'Spielerstatistiken',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => CommunityStatisticsPlayersPage(
                  communityName: communityName,
                  data: data,
                ),
              ),
            ),
          ),
          SportMenuAction(
            icon: Icons.auto_awesome,
            label: 'Highlight-Liste',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => CommunityHighlightsPage(
                  communityId: data.communityId,
                  communityName: communityName,
                  tournaments: data.tournaments,
                ),
              ),
            ),
          ),
          SportMenuAction(
            icon: Icons.trending_up,
            label: 'Trends',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => CommunityTrendsPage(
                  communityName: communityName,
                  data: data,
                ),
              ),
            ),
          ),
        ],
      ),
    ],
  );
}
