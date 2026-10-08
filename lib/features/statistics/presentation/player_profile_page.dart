import '../../personal_profile/data/personal_profile_repository.dart';
import '../data/profile_heatmap_repository.dart';
import '../domain/analytics/community_profile_reports.dart';
import '../../../shared/widgets/sport_menu.dart';
import '../data/scorer_heatmap_repository.dart';
import '../domain/cockpit_heatmap_selection.dart';
import '../domain/analytics/statistics_report.dart';
import 'analytics/player_analytics_page.dart';
import '../../personal_profile/presentation/personal_profile_section.dart';
import 'package:flutter/material.dart';
import '../../scorer/presentation/scorer_page.dart';
import '../../../shared/widgets/adaptive_content.dart';
import '../../accounts/domain/account_user.dart';
import '../../accounts/data/supabase_account_config.dart';
import '../../communities/data/supabase_community_repository.dart';
import '../../communities/domain/community_member_identity.dart';
import '../../tournaments/data/app_database.dart';
import '../../tournaments/domain/tournament_models.dart';
import '../data/player_statistics_repository.dart';
import '../domain/saved_scorer_match.dart';

class PlayerProfilePage extends StatefulWidget {
  const PlayerProfilePage({super.key, required this.account, this.repository});
  final AccountUser account;
  final PlayerStatisticsRepository? repository;
  @override
  State<PlayerProfilePage> createState() => _PlayerProfilePageState();
}

class _PlayerProfilePageState extends State<PlayerProfilePage> {
  late final repository = widget.repository ?? PlayerStatisticsRepository();
  late Future<
    (
      List<SavedScorerMatch>,
      List<CreatedTournament>,
      List<ScorerHeatmapSession>,
    )
  >
  content;
  String? notice;
  String favoriteDouble = '';
  final profileHeatmaps = ProfileHeatmapRepository();
  final ownIds = <String>{};
  final aliases = <String, String>{};
  final communityNames = <String, String>{};
  final tournamentCommunities = <String, String>{};
  @override
  void initState() {
    super.initState();
    content = _load();
  }

  Future<
    (
      List<SavedScorerMatch>,
      List<CreatedTournament>,
      List<ScorerHeatmapSession>,
    )
  >
  _load() async {
    notice = null;
    await repository.synchronize(widget.account.id);
    final history = await repository.load(widget.account.id);
    final tournaments = <String, CreatedTournament>{};
    ownIds
      ..clear()
      ..add(widget.account.id);
    aliases.clear();
    communityNames.clear();
    tournamentCommunities.clear();
    final local = await repository.storage.loadTournaments();
    for (final t in local) {
      tournaments[t.id] = t;
      if (t.communityId != null) tournamentCommunities[t.id] = t.communityId!;
    }
    try {
      for (final p in await LocalAppDatabase().loadPlayerProfiles()) {
        if (p.userId == widget.account.id) ownIds.add(p.id);
      }
      if (SupabaseAccountBootstrap.isInitialized) {
        final communities = SupabaseCommunityRepository();
        if (communities.currentUserId == widget.account.id) {
          for (final community in await communities.loadMyCommunities()) {
            communityNames[community.id] = community.name;
            try {
              final members = effectiveCommunityMembers(
                await communities.loadMembers(community.id),
              );
              for (final member in members) {
                if (member.userId != widget.account.id) continue;
                if (member.playerProfileId != null) {
                  ownIds.add(member.playerProfileId!);
                }
                for (final alias in member.aliasProfileIds) {
                  aliases[alias] = widget.account.id;
                }
              }
              for (final t in await communities.loadTournaments(community.id)) {
                tournaments[t.id] = t;
                tournamentCommunities[t.id] = community.id;
              }
            } catch (_) {
              notice =
                  'Einige Community-Daten konnten nicht geladen werden. Verfügbare Ergebnisse bleiben sichtbar.';
            }
          }
        }
      }
    } catch (_) {
      notice =
          'Turnierdaten möglicherweise unvollständig. Gespeicherte Daten bleiben sichtbar.';
    }
    try {
      favoriteDouble = (await PersonalProfileRepository().load(
        widget.account.id,
        widget.account.displayName,
      )).favoriteDouble;
    } catch (_) {
      favoriteDouble = '';
    }
    var heatmaps = <ScorerHeatmapSession>[];
    try {
      heatmaps = selectProfileHeatmaps(
        await ScorerHeatmapRepository().load(),
        history,
      );
      final owned = {for (final match in history) match.id: match};
      for (final session in heatmaps) {
        await profileHeatmaps.save(
          widget.account.id,
          session,
          owned[session.id]!.playerIndex,
          onlyIfAbsent: true,
        );
      }
    } catch (_) {
      notice =
          '${notice == null ? '' : '$notice\n'}Ältere Heatmap-Daten konnten nicht übernommen werden.';
    }
    await profileHeatmaps.synchronize(widget.account.id);
    try {
      heatmaps = await profileHeatmaps.load(widget.account.id);
    } catch (_) {
      notice =
          '${notice == null ? '' : '$notice\n'}Gespeicherte Profil-Heatmaps konnten nicht geladen werden.';
    }
    return (history, tournaments.values.toList(), heatmaps);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Mein Profil'),
      actions: [
        IconButton(
          tooltip: 'Statistiken synchronisieren',
          icon: const Icon(Icons.sync),
          onPressed: () => setState(() => content = _load()),
        ),
      ],
    ),
    body:
        FutureBuilder<
          (
            List<SavedScorerMatch>,
            List<CreatedTournament>,
            List<ScorerHeatmapSession>,
          )
        >(
          future: content,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return AdaptiveContentList(
                children: [
                  PersonalProfileSection(
                    accountId: widget.account.id,
                    defaultName: widget.account.displayName,
                  ),
                  const Text('Profilstatistiken konnten nicht geladen werden.'),
                  FilledButton(
                    onPressed: () => setState(() => content = _load()),
                    child: const Text('Erneut versuchen'),
                  ),
                ],
              );
            }
            final (allHistory, tournaments, heatmaps) = snapshot.data!;
            String number(double? value) => value?.toStringAsFixed(2) ?? '—';
            return PlayerAnalyticsPage(
              embedded: true,
              name: widget.account.displayName,
              favoriteDouble: favoriteDouble,
              scorer: const StatisticsAnalytics().scorer(allHistory),
              heatmapSessions: heatmaps,
              communityNames: communityNames,
              communityReports: communityProfileReports(
                tournaments: tournaments,
                tournamentCommunities: tournamentCommunities,
                ownIds: ownIds,
                aliases: aliases,
                communities: communityNames.keys.toSet(),
              ),
              tournaments: const StatisticsAnalytics()
                  .tournaments(tournaments, aliases: aliases)
                  .filtered(players: ownIds),
              header: [
                PersonalProfileSection(
                  accountId: widget.account.id,
                  defaultName: widget.account.displayName,
                ),
                Text(widget.account.email),
                const SizedBox(height: 16),
                SportMenuGroup(
                  title: 'Mit meinem Profil',
                  actions: [
                    SportMenuAction(
                      label: 'Scorer mit meinem Profil starten',
                      icon: Icons.sports_score,
                      onTap: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => ScorerPage(account: widget.account),
                          ),
                        );
                        if (mounted) setState(() => content = _load());
                      },
                    ),
                  ],
                ),
                Text(repository.status),
                Text(profileHeatmaps.status),
                if (notice != null) Text(notice!),
              ],
              footerBuilder: (period) {
                final history = allHistory
                    .where((m) => period == null || period.contains(m.playedAt))
                    .toList();
                return [
                  const SizedBox(height: 24),
                  if (history.every((m) => m.visits.isEmpty))
                    const Text('Keine Aufnahmen im gewählten Zeitraum.'),
                  Text(
                    'Gespeicherte Spiele',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  for (final match in history.where((m) => m.visits.isNotEmpty))
                    Card(
                      child: ListTile(
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => PlayerAnalyticsPage(
                                name: match.names.join(' · '),
                                favoriteDouble: favoriteDouble,
                                scorer: const StatisticsAnalytics().scorer([
                                  match,
                                ]),
                                heatmapSessions: heatmaps
                                    .where((s) => s.id == match.id)
                                    .toList(),
                                tournaments: const StatisticsAnalytics()
                                    .tournaments([]),
                              ),
                            ),
                          );
                        },
                        title: Text(match.names.join(' · ')),
                        subtitle: Text(
                          '${match.playedAt.toLocal().toString().substring(0, 16)}\n'
                          '${match.isDraw
                              ? 'Unentschieden'
                              : match.winner == null
                              ? 'Nicht beendet'
                              : match.winner == match.playerIndex
                              ? 'Gewonnen'
                              : 'Verloren'} · '
                          'Average: ${number(match.statistics.average)} · 180er: ${match.statistics.scores180}',
                        ),
                      ),
                    ),
                ];
              },
            );
          },
        ),
  );
}
