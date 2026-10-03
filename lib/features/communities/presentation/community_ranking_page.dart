import 'package:flutter/material.dart';
import '../../../shared/widgets/adaptive_content.dart';
import '../../tournaments/domain/tournament_models.dart';
import '../domain/community.dart';
import '../domain/community_elo.dart';
import '../domain/community_ranking_action.dart';
import '../domain/community_member_identity.dart';
import '../data/supabase_community_repository.dart';
import 'widgets/ranking_player_menu.dart';
import 'community_ranking_history_page.dart';

class CommunityRankingPage extends StatefulWidget {
  const CommunityRankingPage({
    super.key,
    required this.communityName,
    required this.members,
    required this.tournaments,
    this.showAppBar = true,
    this.rankingId = 'default',
    this.communityId,
    this.repository,
    this.canManage = false,
  });

  final String communityName;
  final List<CommunityMember> members;
  final List<CreatedTournament> tournaments;
  final bool showAppBar;
  final String rankingId;
  final String? communityId;
  final SupabaseCommunityRepository? repository;
  final bool canManage;

  @override
  State<CommunityRankingPage> createState() => _CommunityRankingPageState();
}

class _CommunityRankingPageState extends State<CommunityRankingPage> {
  bool _currentYearOnly = true;
  List<CommunityRankingAction> _actions = [];
  bool _loading = false, _failed = false, _busy = false;

  @override
  void initState() {
    super.initState();
    if (widget.communityId != null) _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final actions = await widget.repository!.loadRankingActions(
        widget.communityId!,
      );
      if (mounted) {
        setState(() {
          _actions = actions;
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

  Future<void> _manage(
    CommunityMember member,
    RankingPlayerAction action,
  ) async {
    if (_busy || !widget.canManage || widget.repository == null) return;
    if (!await confirmRankingPlayerAction(
          context,
          member.displayName,
          widget.communityName,
          action,
        ) ||
        !mounted) {
      return;
    }
    setState(() => _busy = true);
    try {
      final applied = await widget.repository!.manageRankingPlayer(
        widget.communityId!,
        widget.rankingId,
        member.playerProfileId ?? member.displayName,
        action,
      );
      if (mounted) {
        setState(() => _actions = [..._actions, applied]);
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              action == RankingPlayerAction.reset
                  ? 'Spielerwertung zurückgesetzt. Sichtbar nach dem nächsten gewerteten Spiel.'
                  : 'Spieler aus dieser Rangliste entfernt.',
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Änderung nicht bestätigt. Verbindung und Rechte prüfen; Rangliste erneut laden.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = const CommunityEloCalculator().calculate(
      members: widget.members,
      tournaments: widget.tournaments,
      currentYearOnly: _currentYearOnly,
      rankingId: widget.rankingId,
      actions: _actions,
    );
    return Scaffold(
      appBar: widget.showAppBar
          ? AppBar(title: Text('Rangliste · ${widget.communityName}'))
          : null,
      body: AdaptiveContentList(
        padding: const EdgeInsets.all(16),
        children: [
          if (widget.communityId != null)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _loading || _busy ? null : _load,
                icon: const Icon(Icons.refresh),
                label: const Text('Rangliste aktualisieren'),
              ),
            ),
          if (_loading) const LinearProgressIndicator(),
          if (_failed)
            const Text(
              'Ranglistenverwaltung konnte nicht geladen werden. Bitte erneut versuchen.',
            ),
          if (!_loading && !_failed) ...[
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: true, label: Text('Dieses Jahr')),
                ButtonSegment(value: false, label: Text('Gesamt')),
              ],
              selected: {_currentYearOnly},
              onSelectionChanged: (value) =>
                  setState(() => _currentYearOnly = value.first),
            ),
            const SizedBox(height: 16),
            const Text(
              'Startwert: 1000 Elo · Standard-Elo-Formel · K-Faktor 32',
            ),
            const SizedBox(height: 12),
            if (snapshot.entries.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Noch keine gewerteten Spiele im ausgewählten Zeitraum.',
                  ),
                ),
              )
            else
              Card(
                child: Column(
                  children: [
                    for (
                      var index = 0;
                      index < snapshot.entries.length;
                      index++
                    )
                      RankingPlayerTile(
                        position: index + 1,
                        title:
                            '${snapshot.entries[index].player.displayName} · ${snapshot.entries[index].rating} Elo',
                        subtitle:
                            '${snapshot.entries[index].wins} Siege · ${snapshot.entries[index].draws} Unentschieden · ${snapshot.entries[index].losses} Niederlagen · ${snapshot.entries[index].matches} Spiele',
                        menu: widget.canManage
                            ? RankingPlayerMenu(
                                onAction: _busy
                                    ? null
                                    : (action) => _manage(
                                        snapshot.entries[index].player,
                                        action,
                                      ),
                              )
                            : null,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => CommunityRankingHistoryPage(
                              entry: snapshot.entries[index],
                              history:
                                  snapshot.history[snapshot
                                          .entries[index]
                                          .player
                                          .playerProfileId ??
                                      snapshot
                                          .entries[index]
                                          .player
                                          .displayName] ??
                                  const [],
                              currentYearOnly: _currentYearOnly,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            if (widget.canManage)
              ExpansionTile(
                title: const Text('Spieler ohne Ranglistenplatz verwalten'),
                children: [
                  for (final member in effectiveCommunityMembers(
                    widget.members,
                  ))
                    if (!snapshot.entries.any(
                      (e) =>
                          (e.player.playerProfileId ?? e.player.displayName) ==
                          (member.playerProfileId ?? member.displayName),
                    ))
                      RankingPlayerTile(
                        title: member.displayName,
                        subtitle:
                            snapshot.excludedPlayerKeys.contains(
                              member.playerProfileId ?? member.displayName,
                            )
                            ? 'Aus dieser Rangliste entfernt'
                            : 'Keine gewerteten Spiele in diesem Zeitraum',
                        menu: RankingPlayerMenu(
                          excluded: snapshot.excludedPlayerKeys.contains(
                            member.playerProfileId ?? member.displayName,
                          ),
                          onAction: _busy
                              ? null
                              : (action) => _manage(member, action),
                        ),
                      ),
                ],
              ),
          ],
        ],
      ),
    );
  }
}
