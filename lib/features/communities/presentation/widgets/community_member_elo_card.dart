import 'package:flutter/material.dart';

import '../../domain/community_elo.dart';
import '../../domain/community.dart';
import '../../domain/community_statistics.dart';
import '../community_ranking_history_page.dart';

class CommunityMemberEloCard extends StatelessWidget {
  const CommunityMemberEloCard({
    super.key,
    required this.data,
    required this.member,
  });

  final CommunityStatistics data;
  final CommunityMember member;

  @override
  Widget build(BuildContext context) {
    final snapshot = const CommunityEloCalculator().calculate(
      members: data.members,
      tournaments: data.tournaments,
      currentYearOnly: false,
    );
    final memberId = member.playerProfileId ?? member.displayName;
    final entry = snapshot.entries
        .where(
          (item) =>
              item.player.playerProfileId == memberId ||
              item.player.displayName == member.displayName,
        )
        .firstOrNull;
    final history = snapshot.history[memberId] ?? const [];
    final statsId = data.aliases[memberId] ?? memberId;
    final stats = data.rows().where((row) => row.id == statsId).firstOrNull;
    final participations = stats?.tournaments.length ?? 0;
    final wins = stats?.wins ?? 0;
    final matches = stats?.matches ?? 0;
    final winRate = matches == 0 ? null : 100 * wins / matches;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Turnierbilanz',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text('$participations Turnierteilnahmen · $wins Matchsiege'),
            Text(
              'Match-Siegquote: ${winRate == null ? '—' : '${winRate.toStringAsFixed(1)} %'}',
            ),
            const SizedBox(height: 12),
            Text(
              'Ranglistenwertung',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (entry == null)
              const Text('Noch keine gewerteten Spiele · Startwert 1000 Elo')
            else ...[
              Text('${entry.rating} Elo · ${entry.matches} gewertete Spiele'),
              TextButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => CommunityRankingHistoryPage(
                      entry: entry,
                      history: history,
                      currentYearOnly: false,
                    ),
                  ),
                ),
                icon: const Icon(Icons.timeline),
                label: const Text('Elo-Verlauf und Begegnungen öffnen'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
