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
import '../domain/tournament_player_statistics.dart';
import 'tournament_statistics_view.dart';
import '../domain/statistics_period.dart';
import 'statistics_period_filter.dart';

class PlayerProfilePage extends StatefulWidget {
  const PlayerProfilePage({super.key, required this.account, this.repository});
  final AccountUser account;
  final PlayerStatisticsRepository? repository;
  @override
  State<PlayerProfilePage> createState() => _PlayerProfilePageState();
}

class _PlayerProfilePageState extends State<PlayerProfilePage> {
  late final repository = widget.repository ?? PlayerStatisticsRepository();
  late Future<(List<SavedScorerMatch>, List<CreatedTournament>)> content;
  String? notice;
  StatisticsPeriod? period;
  String periodLabel = 'Gesamt';
  final ownIds = <String>{};
  final aliases = <String, String>{};
  @override
  void initState() {
    super.initState();
    content = _load();
  }

  Future<(List<SavedScorerMatch>, List<CreatedTournament>)> _load() async {
    notice = null;
    await repository.synchronize(widget.account.id);
    final history = await repository.load(widget.account.id);
    final tournaments = <String, CreatedTournament>{};
    ownIds
      ..clear()
      ..add(widget.account.id);
    aliases.clear();
    final local = await repository.storage.loadTournaments();
    for (final t in local) {
      tournaments[t.id] = t;
    }
    try {
      for (final p in await LocalAppDatabase().loadPlayerProfiles()) {
        if (p.userId == widget.account.id) ownIds.add(p.id);
      }
      if (SupabaseAccountBootstrap.isInitialized) {
        final communities = SupabaseCommunityRepository();
        if (communities.currentUserId == widget.account.id) {
          for (final community in await communities.loadMyCommunities()) {
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
            }
          }
        }
      }
    } catch (_) {
      notice =
          'Turnierdaten möglicherweise unvollständig. Gespeicherte Daten bleiben sichtbar.';
    }
    return (history, tournaments.values.toList());
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
    body: FutureBuilder<(List<SavedScorerMatch>, List<CreatedTournament>)>(
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
        final (allHistory, tournaments) = snapshot.data!;
        final history = allHistory
            .where((m) => period == null || period!.contains(m.playedAt))
            .toList();
        final rows = const TournamentStatisticsCalculator()
            .calculate(tournaments, aliases: aliases, period: period)
            .where((row) => ownIds.contains(row.id))
            .toList();
        final totals = PersonalScorerTotals(history);
        String number(double? value) => value?.toStringAsFixed(2) ?? '—';
        return AdaptiveContentList(
          children: [
            PersonalProfileSection(
              accountId: widget.account.id,
              defaultName: widget.account.displayName,
            ),
            Text(widget.account.email),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ScorerPage(account: widget.account),
                  ),
                );
                if (mounted) {
                  setState(() => content = _load());
                }
              },
              icon: const Icon(Icons.sports_score),
              label: const Text('Scorer mit meinem Profil starten'),
            ),
            Text(repository.status),
            StatisticsPeriodFilter(
              selected: periodLabel,
              period: period,
              onChanged: (label, value) => setState(() {
                period = value;
                periodLabel = label;
              }),
            ),
            if (notice != null) Text(notice!),
            const SizedBox(height: 24),
            Text(
              'Scorer-Statistiken',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const Text(
              'Nur Spiele, bei denen du dich deinem Profil zugeordnet hast. Auch erfasste Aufnahmen nicht beendeter Spiele bleiben erhalten.',
            ),
            if (totals.sessions == 0)
              const Text('Keine Aufnahmen im gewählten Zeitraum.'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  '${totals.sessions} Sitzungen · ${totals.completed} beendete Spiele · ${totals.wins} Siege\n'
                  '3-Dart-Average: ${number(totals.average)}\n'
                  '180er: ${totals.scores180} · Höchstes Finish: ${totals.highestFinish}\n'
                  'Gewonnene Legs: ${totals.legsWon} / ${totals.legs}\n'
                  'Checkoutquote (Double Out): ${number(totals.checkoutPercent)}${totals.checkoutPercent == null ? '' : ' %'}'
                  '${totals.unknownAttempts > 0 ? '\nCheckoutversuche unvollständig erfasst.' : ''}',
                ),
              ),
            ),
            Text(
              'Gespeicherte Spiele',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            for (final match in history.where((m) => m.visits.isNotEmpty))
              Card(
                child: ListTile(
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    final p = match.statistics;
                    showDialog<void>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Meine Spielstatistik'),
                        scrollable: true,
                        content: Text(
                          '${match.names.join(' · ')}\n\n'
                          '3-Dart-Average: ${number(p.average)}\nFirst-9-Average: ${number(p.firstNineAverage)}\n'
                          'Punkte: ${p.points} · Darts: ${p.darts} · Aufnahmen: ${p.visits}\n'
                          '60+: ${p.scores60} · 100+: ${p.scores100} · 140+: ${p.scores140} · 180: ${p.scores180}\n'
                          'Höchste Aufnahme: ${p.highestScore} · Höchstes Finish: ${p.highestFinish}\n'
                          'Gewonnene Legs: ${p.legsWon}/${p.legsPlayed} · Bestes Leg: ${p.bestLeg ?? '—'} Darts\n'
                          'Überworfen: ${p.busts} · Breaks: ${p.breaks} · Holds: ${p.holds}\n'
                          '${match.doubleOut ? 'Checkoutquote: ${number(p.checkoutPercent)}${p.checkoutPercent == null ? '' : ' %'}\nUnbekannte Checkout-Aufnahmen: ${p.unknownCheckoutVisits}' : ''}',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Schließen'),
                          ),
                        ],
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
            const SizedBox(height: 24),
            Text(
              'Turnierstatistiken',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const Text(
              'Zuordnung über Spielerprofile; reine Namensgleichheit genügt nicht.',
            ),
            if (rows.isEmpty)
              const Text(
                'Keine deinem Profil zugeordneten Turnierergebnisse im gewählten Zeitraum.',
              ),
            for (final row in rows) TournamentStatisticsCard(row: row),
          ],
        );
      },
    ),
  );
}
