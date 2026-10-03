import 'package:flutter/material.dart';
import '../../../shared/widgets/adaptive_content.dart';
import '../../statistics/presentation/tournament_statistics_view.dart';
import '../data/supabase_community_repository.dart';
import '../domain/community.dart';
import '../domain/community_statistics.dart';
import 'community_player_statistics_page.dart';

class CommunityMemberProfilePage extends StatefulWidget {
  const CommunityMemberProfilePage({
    super.key,
    required this.community,
    required this.member,
    required this.members,
    required this.repository,
  });
  final Community community;
  final CommunityMember member;
  final List<CommunityMember> members;
  final SupabaseCommunityRepository repository;
  @override
  State<CommunityMemberProfilePage> createState() => _ProfileState();
}

class _ProfileState extends State<CommunityMemberProfilePage> {
  late Future<CommunityStatistics> _future = _load();
  Future<CommunityStatistics> _load() async => CommunityStatistics(
    communityId: widget.community.id,
    members: widget.members,
    tournaments: await widget.repository.loadTournaments(widget.community.id),
  );
  @override
  Widget build(BuildContext context) {
    final member = widget.member;
    final joined = member.joinedAt.toLocal();
    final linked = widget.members
        .where((m) => m.userId != null && m.userId == member.linkedUserId)
        .firstOrNull;
    return Scaffold(
      appBar: AppBar(title: const Text('Mitgliederprofil')),
      body: AdaptiveContentList(
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    member.isManual
                        ? Icons.person_outline
                        : Icons.account_circle_outlined,
                    size: 48,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    member.displayName,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  Text(widget.community.name),
                  const SizedBox(height: 12),
                  Text(
                    member.userId == widget.community.ownerUserId
                        ? 'Community-Inhaber'
                        : member.isManual
                        ? 'Manuelles Mitglied'
                        : 'Mitglied mit Account',
                  ),
                  Text(
                    'Mitglied seit ${joined.day}.${joined.month}.${joined.year}',
                  ),
                  if (member.isManual)
                    Text(
                      linked == null
                          ? 'Keinem Community-Account zugeordnet'
                          : 'Zugeordneter Account: ${linked.displayName}',
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Community-Statistik',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          FutureBuilder<CommunityStatistics>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const LinearProgressIndicator();
              }
              if (snapshot.hasError) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Die Statistik konnte nicht geladen werden.'),
                    TextButton(
                      onPressed: () => setState(() => _future = _load()),
                      child: const Text('Erneut versuchen'),
                    ),
                  ],
                );
              }
              final data = snapshot.data!;
              final originalId =
                  member.playerProfileId ??
                  'member:${member.userId ?? member.displayName}';
              final id = data.aliases[originalId] ?? originalId;
              final player =
                  data.players.where((p) => p.id == id).firstOrNull ??
                  CommunityStatisticsPlayer(id, member.displayName);
              final row = data.rows().where((r) => r.id == id).firstOrNull;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (linked != null)
                    const Text(
                      'Die Statistik wird mit dem zugeordneten Account zusammengeführt.',
                    ),
                  if (row == null)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        'Noch keine abgeschlossenen Spiele in dieser Community.',
                      ),
                    ),
                  if (row != null)
                    TournamentStatisticsCard(row: row, playerName: player.name),
                  FilledButton.icon(
                    icon: const Icon(Icons.query_stats),
                    label: const Text('Persönliche Statistik öffnen'),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => CommunityPlayerStatisticsPage(
                          communityName: widget.community.name,
                          data: data,
                          player: player,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
