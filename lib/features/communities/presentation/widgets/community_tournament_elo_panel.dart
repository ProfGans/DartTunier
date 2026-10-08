import 'package:flutter/material.dart';
import '../../../../shared/widgets/adaptive_content.dart';
import '../../../tournaments/domain/tournament_models.dart';
import '../../data/supabase_community_repository.dart';
import '../../domain/community.dart';
import '../../domain/community_ranking.dart';
import '../../domain/community_ranking_action.dart';
import '../../application/community_tournament_elo.dart';
import '../../application/community_live_ranking.dart';
import 'community_live_ranking_view.dart';

class TournamentEloData {
  const TournamentEloData({
    required this.enabled,
    required this.members,
    required this.tournaments,
    required this.rankings,
    this.actions = const [],
  });
  final bool enabled;
  final List<CommunityMember> members;
  final List<CreatedTournament> tournaments;
  final List<CommunityRanking> rankings;
  final List<CommunityRankingAction> actions;
}

class CommunityTournamentEloPanel extends StatefulWidget {
  const CommunityTournamentEloPanel({
    super.key,
    required this.tournament,
    required this.activeStage,
    this.load,
  });
  final CreatedTournament tournament;
  final int activeStage;
  final Future<TournamentEloData> Function()? load;

  @override
  State<CommunityTournamentEloPanel> createState() => _PanelState();
}

class _PanelState extends State<CommunityTournamentEloPanel>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  TournamentEloData? _data;
  bool _loading = true, _failed = false, _yearOnly = true;
  String? _ranking;
  bool _showLiveRanking = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final data = await (widget.load?.call() ?? _loadRepository());
      if (mounted) {
        setState(() {
          _data = data;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _failed = true;
          _loading = false;
        });
      }
    }
  }

  Future<TournamentEloData> _loadRepository() async {
    final repository = SupabaseCommunityRepository();
    final id = widget.tournament.communityId!;
    final communities = await repository.loadMyCommunities();
    final community = communities.where((c) => c.id == id).firstOrNull;
    if (community == null) throw StateError('Community nicht verfügbar');
    if (!community.rankingEnabled) {
      return const TournamentEloData(
        enabled: false,
        members: [],
        tournaments: [],
        rankings: [],
      );
    }
    final results = await Future.wait<Object>([
      repository.loadMembers(id),
      repository.loadTournaments(id),
      repository.loadRankings(id),
      repository.loadRankingActions(id),
    ]);
    return TournamentEloData(
      enabled: true,
      members: results[0] as List<CommunityMember>,
      tournaments: results[1] as List<CreatedTournament>,
      rankings: results[2] as List<CommunityRanking>,
      actions: results[3] as List<CommunityRankingAction>,
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_data?.enabled == false && !_failed && !_loading) {
      return const SizedBox.shrink();
    }
    final ids = widget.tournament.communityRankingIds.where((id) => _data == null || _data!.rankings.any((r) => r.id == id)).toList();
    if (ids.isEmpty) return const SizedBox.shrink();
    final ranking = ids.contains(_ranking) ? _ranking! : ids.first;
    final data = _data;
    final months = data?.rankings.where((r) => r.id == ranking).firstOrNull?.validityMonths;
    final players = data == null || _loading || _failed || _showLiveRanking
        ? <TournamentEloPlayer>[]
        : const CommunityTournamentElo().calculate(
            tournament: widget.tournament,
            tournaments: data.tournaments,
            members: data.members,
            actions: data.actions,
            rankingId: ranking,
            validityMonths: data.rankings.where((r) => r.id == ranking).firstOrNull?.validityMonths,
            currentYearOnly: _yearOnly,
            activeStage: widget.activeStage,
          );
    String signed(int value) => value > 0 ? '+$value' : '$value';
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1120),
        child: Card(
          child: ExpansionTile(
            key: PageStorageKey('tournament-elo-${widget.tournament.id}'),
            initiallyExpanded: true,
            title: const Text('Spieler · Elo und nächstes Spiel'),
            childrenPadding: const EdgeInsets.all(12),
            children: [
              if (_loading) const LinearProgressIndicator(),
              if (_failed)
                const Text(
                  'Elo konnte nicht geladen werden. Verbindung prüfen und erneut laden.',
                ),
              if (!_loading)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: _load,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Elo aktualisieren'),
                  ),
                ),
              if (data != null && !_failed && !_loading) ...[
                DropdownButtonFormField<String>(
                  initialValue: ranking,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Rangliste'),
                  items: [
                    for (final id in ids)
                      DropdownMenuItem(
                        value: id,
                        child: Text(
                          data.rankings
                                  .where((r) => r.id == id)
                                  .firstOrNull
                                  ?.name ??
                              (id == 'default'
                                  ? 'Standard-Rangliste'
                                  : 'Rangliste $id'),
                        ),
                      ),
                  ],
                  onChanged: (value) => setState(() => _ranking = value),
                ),
                if (months != null) Text('Gewertet werden die letzten $months Monate.'),
                if (months == null) SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Dieses Jahr'),
                  subtitle: Text(
                    _yearOnly
                        ? 'Elo der Jahresrangliste'
                        : 'Elo der Gesamtrangliste',
                  ),
                  value: _yearOnly,
                  onChanged: (v) => setState(() => _yearOnly = v),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Live-Rangliste anzeigen'),
                  subtitle: const Text(
                    'Platzierung sowie Platz- und Elo-Veränderung durch dieses Turnier',
                  ),
                  value: _showLiveRanking,
                  onChanged: (value) =>
                      setState(() => _showLiveRanking = value),
                ),
                if (_showLiveRanking)
                  CommunityLiveRankingView(
                    entries: const CommunityLiveRanking().calculate(
                      tournament: widget.tournament,
                      tournaments: data.tournaments,
                      members: data.members,
                      actions: data.actions,
                      rankingId: ranking,
            validityMonths: data.rankings.where((r) => r.id == ranking).firstOrNull?.validityMonths,
                      currentYearOnly: _yearOnly,
                    ),
                  )
                else ...[
                  const Text(
                    'Vorschau mit den aktuell geladenen Ergebnissen. Neue Ergebnisse können die möglichen Änderungen verschieben. Neue Spieler starten mit 1000 Elo.',
                  ),
                  const SizedBox(height: 12),
                  AdaptiveTileLayout(
                    children: [
                      for (final p in players)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Theme.of(context).dividerColor,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${p.player.name} · ${p.rating == null ? 'Elo nicht verfügbar' : '${p.rating} Elo'}',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              if (p.win != null) ...[
                                Text('Nächstes Spiel gegen ${p.opponent}'),
                                Text(
                                  'Sieg ${signed(p.win!)} · Niederlage ${signed(p.loss!)}'
                                  '${p.draw == null ? '' : ' · Unentschieden ${signed(p.draw!)}'}',
                                ),
                              ] else
                                Text(
                                  p.player.isTeam
                                      ? 'Für Teams ist keine Elo-Wertung definiert.'
                                      : p.rating == null || p.opponent != null
                                      ? 'Keine eindeutige Ranglisten-Zuordnung für diese Paarung.'
                                      : 'Noch kein nächstes gewertetes Spiel feststehend.',
                                ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}
