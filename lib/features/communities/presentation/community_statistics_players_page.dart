import 'package:flutter/material.dart';
import '../../../shared/widgets/adaptive_content.dart';
import '../domain/community_statistics.dart';
import 'community_player_statistics_page.dart';
import 'widgets/community_statistics_link.dart';

class CommunityStatisticsPlayersPage extends StatefulWidget {
  const CommunityStatisticsPlayersPage({
    super.key,
    required this.communityName,
    required this.data,
  });
  final String communityName;
  final CommunityStatistics data;
  @override
  State<CommunityStatisticsPlayersPage> createState() => _PlayersState();
}

class _PlayersState extends State<CommunityStatisticsPlayersPage> {
  String _query = '';
  late final _players = widget.data.players;
  late final _rows = {for (final row in widget.data.rows()) row.id: row};
  @override
  Widget build(BuildContext context) {
    final players = _players
        .where(
          (p) => p.name.toLowerCase().contains(_query.trim().toLowerCase()),
        )
        .toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Spielerstatistiken')),
      body: AdaptiveContentList(
        children: [
          Text(
            widget.communityName,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          TextField(
            decoration: const InputDecoration(
              labelText: 'Spieler suchen',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
            onChanged: (value) => setState(() => _query = value),
          ),
          const SizedBox(height: 16),
          if (players.isEmpty)
            Text(
              _players.isEmpty
                  ? 'Noch keine Spieler in dieser Community.'
                  : 'Keine Spieler gefunden.',
            ),
          for (final player in players)
            CommunityStatisticsLink(
              title: player.name,
              subtitle:
                  '${_rows[player.id]?.matches ?? 0} Spiele · ${_rows[player.id]?.tournaments.length ?? 0} Turniere',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => CommunityPlayerStatisticsPage(
                    communityName: widget.communityName,
                    data: widget.data,
                    player: player,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
