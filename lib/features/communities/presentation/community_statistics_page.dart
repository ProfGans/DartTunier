import 'package:flutter/material.dart';
import '../../../shared/widgets/adaptive_content.dart';
import '../../statistics/presentation/tournament_statistics_view.dart';
import '../domain/community_statistics.dart';
import 'community_statistics_players_page.dart';
import 'widgets/community_statistics_link.dart';
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
  Widget build(BuildContext context) => AdaptiveContentList(
    children: [
      Text(
        'Statistik-Rubriken',
        style: Theme.of(context).textTheme.headlineSmall,
      ),
      const SizedBox(height: 16),
      CommunityStatisticsLink(
        icon: Icons.person_outline,
        title: 'Spielerstatistiken',
        subtitle:
            'Spieler auswählen und seine persönliche Statistikseite öffnen.',
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => CommunityStatisticsPlayersPage(
              communityName: communityName,
              data: data,
            ),
          ),
        ),
      ),
      CommunityStatisticsLink(
        icon: Icons.compare_arrows,
        title: 'Spielervergleich',
        subtitle: 'Die bisherigen Gesamtwerte aller Spieler im Überblick.',
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => Scaffold(
              appBar: AppBar(title: Text('Spielervergleich · $communityName')),
              body: TournamentStatisticsView(
                rows: data.rows(),
                title: 'Spielervergleich',
              ),
            ),
          ),
        ),
      ),
      CommunityStatisticsLink(
        icon: Icons.auto_awesome,
        title: 'Highlight-Liste',
        subtitle:
            'Besondere Leistungen ansehen, filtern und mit Berechtigung verwalten.',
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
      CommunityStatisticsLink(
        icon: Icons.trending_up,
        title: 'Trends',
        subtitle:
            'Spieler im Aufwind, Practice Board und Formvergleich der letzten drei Monate.',
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) =>
                CommunityTrendsPage(communityName: communityName, data: data),
          ),
        ),
      ),
    ],
  );
}
