import 'package:flutter/material.dart';
import '../../../shared/widgets/adaptive_content.dart';
import '../../tournaments/data/tournament_storage.dart';
import '../../tournaments/domain/tournament_models.dart';
import '../application/community_tournament_import.dart';
import '../data/supabase_community_repository.dart';
import '../domain/community.dart';
import '../domain/community_member_identity.dart';
import 'widgets/community_ranking_picker.dart';

class CommunityTournamentImportPage extends StatefulWidget {
  const CommunityTournamentImportPage({
    super.key,
    required this.community,
    required this.repository,
    this.storage,
  });
  final Community community;
  final SupabaseCommunityRepository repository;
  final TournamentStorage? storage;
  @override
  State<CommunityTournamentImportPage> createState() => _ImportState();
}

class _ImportState extends State<CommunityTournamentImportPage> {
  late final storage = widget.storage ?? TournamentStorage();
  late final future = _load();
  List<CreatedTournament> sources = [];
  List<CommunityMember> members = [];
  CreatedTournament? selected;
  final assignments = <String, CommunityMember>{};
  bool ranked = false, busy = false;
  List<String> rankingIds = ['default'];
  String? error;
  Future<void> _load() async {
    final remote = await widget.repository.loadTournaments(widget.community.id);
    final local = await storage.loadTournaments();
    final existing = {...remote.map((t) => t.id), ...local.map((t) => t.id)};
    sources = local
        .where(
          (t) =>
              t.communityId == null &&
              !existing.contains(
                CommunityTournamentImport.id(widget.community.id, t.id),
              ),
        )
        .toList();
    members = effectiveCommunityMembers(
      await widget.repository.loadMembers(widget.community.id),
    );
  }

  Future<void> _import() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final copy = CommunityTournamentImport.copy(
        selected!,
        widget.community.id,
        assignments: assignments,
        countsForRanking: ranked,
        rankingIds: ranked ? rankingIds : [],
      );
      await storage.saveTournament(copy);
      // The existing persistent upload queue keeps the import safe offline.
      await storage.synchronize(tournamentId: copy.id);
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(
          () => error =
              'Import nicht abgeschlossen. Verbindung, Berechtigung und eindeutige Spielerzuordnung prüfen.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: Scaffold(
      appBar: AppBar(title: const Text('Lokales Turnier importieren')),
      body: FutureBuilder<void>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(
              child: Text(
                'Lokale Turniere oder Community-Daten konnten nicht geladen werden.',
              ),
            );
          }
          return AdaptiveContentList(
            children: [
              Text(
                widget.community.name,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const Text(
                'Eine Kopie übernimmt Spielplan, Ergebnisse und Scorer-Statistiken. Das lokale Original bleibt erhalten. Bereits importierte Turniere werden nicht erneut angeboten.',
              ),
              if (sources.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    'Keine weiteren lokalen Turniere zum Importieren vorhanden.',
                  ),
                ),
              if (sources.isNotEmpty)
                DropdownButtonFormField<CreatedTournament>(
                  isExpanded: true,
                  itemHeight: null,
                  decoration: const InputDecoration(
                    labelText: 'Lokales Turnier',
                  ),
                  items: [
                    for (final t in sources)
                      DropdownMenuItem(
                        value: t,
                        child: Text('${t.name} · ${t.players.length} Spieler'),
                      ),
                  ],
                  onChanged: busy
                      ? null
                      : (value) => setState(() {
                          selected = value;
                          assignments.clear();
                          for (final p in value!.players.expand(
                            (p) => p.individuals,
                          )) {
                            final member = members
                                .where(
                                  (m) =>
                                      p.profileId != null &&
                                      (m.playerProfileId == p.profileId ||
                                          m.aliasProfileIds.contains(
                                            p.profileId,
                                          )),
                                )
                                .firstOrNull;
                            if (member != null) {
                              assignments[CommunityTournamentImport.playerKey(
                                    p,
                                  )] =
                                  member;
                            }
                          }
                        }),
                ),
              if (selected != null) ...[
                const SizedBox(height: 16),
                const Text(
                  'Spieler zuordnen (optional). Ohne Zuordnung bleiben die bisherigen Spielerkennungen erhalten. Für Elo müssen Spieler Community-Mitgliedern zugeordnet sein.',
                ),
                for (final p in {
                  for (final p in selected!.players.expand(
                    (p) => p.individuals,
                  ))
                    CommunityTournamentImport.playerKey(p): p,
                }.values)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: DropdownButtonFormField<String>(
                      key: ValueKey(
                        '${selected!.id}:${CommunityTournamentImport.playerKey(p)}',
                      ),
                      initialValue:
                          assignments[CommunityTournamentImport.playerKey(p)]
                              ?.playerProfileId ??
                          '',
                      isExpanded: true,
                      itemHeight: null,
                      decoration: InputDecoration(labelText: p.name),
                      items: [
                        const DropdownMenuItem(
                          value: '',
                          child: Text('Ohne neue Zuordnung'),
                        ),
                        for (final m in members.where(
                          (m) => m.playerProfileId != null,
                        ))
                          DropdownMenuItem(
                            value: m.playerProfileId!,
                            child: Text(m.displayName),
                          ),
                      ],
                      onChanged: busy
                          ? null
                          : (id) => setState(() {
                              final key = CommunityTournamentImport.playerKey(
                                p,
                              );
                              if (id == '') {
                                assignments.remove(key);
                              } else {
                                assignments[key] = members.firstWhere(
                                  (m) => m.playerProfileId == id,
                                );
                              }
                            }),
                    ),
                  ),
                if (widget.community.rankingEnabled)
                  SwitchListTile(
                    title: const Text('Import für die Rangliste werten'),
                    subtitle: const Text(
                      'Bereits gespeicherte Ergebnisse können die bisherige Elo verändern.',
                    ),
                    value: ranked,
                    onChanged: busy
                        ? null
                        : (value) => setState(() => ranked = value),
                  ),
                if (ranked)
                  CommunityRankingPicker(
                    communityId: widget.community.id,
                    selectedIds: rankingIds,
                    onChanged: (ids) => setState(() => rankingIds = ids),
                  ),
                if (error != null) Text(error!),
                if (busy) const LinearProgressIndicator(),
                FilledButton.icon(
                  onPressed: busy ? null : _import,
                  icon: const Icon(Icons.file_download_outlined),
                  label: const Text('Als Community-Turnier importieren'),
                ),
              ],
            ],
          );
        },
      ),
    ),
  );
}
