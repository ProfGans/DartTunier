import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../shared/widgets/adaptive_content.dart';
import '../../tournaments/data/tournament_storage.dart';
import '../application/challonge_import_service.dart';
import '../data/challonge_client.dart';
import '../data/challonge_public_reader.dart';
import '../data/supabase_community_repository.dart';
import '../domain/challonge_tournament.dart';
import '../domain/community.dart';
import '../domain/community_permissions.dart';
import '../domain/community_member_identity.dart';
import 'challonge_browser_page.dart';

class ChallongeImportPage extends StatefulWidget {
  const ChallongeImportPage({
    super.key,
    required this.community,
    required this.repository,
    this.client,
    this.storage,
  });
  final Community community;
  final SupabaseCommunityRepository repository;
  final ChallongeClient? client;
  final TournamentStorage? storage;
  @override
  State<ChallongeImportPage> createState() => _ChallongeImportState();
}

class _ChallongeImportState extends State<ChallongeImportPage> {
  final _key = TextEditingController();
  final _community = TextEditingController(
    text:
        'https://challonge.com/de/communities/DC-Unzenberg-Heinzenbach/tournaments',
  );
  final _links = TextEditingController();
  late final _client =
      widget.client ??
      ChallongeClient(
        publicReader: ChallongePublicReader(
          readDocument: (uri) async {
            final source = await Navigator.of(context).push<String>(
              MaterialPageRoute(builder: (_) => ChallongeBrowserPage(uri: uri)),
            );
            if (source == null) {
              throw const FormatException('Öffentlicher Abruf abgebrochen.');
            }
            return source;
          },
        ),
      );
  late final _storage = widget.storage ?? TournamentStorage();
  List<Map<String, dynamic>> _list = [];
  List<ChallongeTournament> _preview = [];
  List<CommunityMember> _members = [];
  final _selected = <String>{};
  final _assignments = <String, String>{};
  Set<String> _existing = {};
  bool _busy = false;
  int _revision = 0;
  String? _status, _error;
  @override
  void dispose() {
    _key.dispose();
    _community.dispose();
    _links.dispose();
    super.dispose();
  }

  Future<void> _work(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = e is FormatException
              ? e.message.toString()
              : e is StateError
              ? e.message.toString()
              : 'Import nicht abgeschlossen. Verbindung und Community-Berechtigung prüfen. Bereits gespeicherte Turniere und Mitglieder werden beim erneuten Versuch wiederverwendet.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _prepare(List<ChallongeTournament> sources) async {
    _members = effectiveCommunityMembers(
      await widget.repository.loadMembers(widget.community.id),
    );
    final remote = await widget.repository.loadTournaments(widget.community.id);
    final local = await _storage.loadTournaments();
    _existing = {...remote.map((t) => t.id), ...local.map((t) => t.id)};
    if (mounted) {
      setState(() {
        _preview = {for (final t in sources) t.id: t}.values.toList();
        _revision++;
        _assignments.clear();
        _status = null;
      });
    }
  }

  Future<void> _load() => _work(() async {
    final list = await _client.list(_key.text, _community.text);
    if (mounted) {
      setState(() {
        _list = list;
        _selected.clear();
        _preview = [];
        _status = _key.text.trim().isEmpty
            ? '${list.length} öffentliche Turnierlinks gefunden. Die Vorschau akzeptiert nur abgeschlossene Turniere.'
            : '${list.length} abgeschlossene Turniere gefunden.';
      });
    }
  });
  Future<void> _previewSelected() => _work(() async {
    final tournaments = <ChallongeTournament>[];
    for (final id in _selected) {
      tournaments.add(await _client.tournament(_key.text, id));
    }
    for (final link
        in _links.text.split(RegExp(r'[\s,;]+')).where((s) => s.isNotEmpty)) {
      final uri = Uri.tryParse(link);
      if (_key.text.trim().isEmpty) {
        ChallongePublicReader.validateUrl(link);
        tournaments.add(await _client.tournament('', link));
        continue;
      }
      var identifier = link;
      if (uri != null && uri.hasScheme) {
        if (!(uri.host == 'challonge.com' ||
                uri.host.endsWith('.challonge.com')) ||
            uri.pathSegments.isEmpty ||
            uri.pathSegments.contains('communities')) {
          throw const FormatException(
            'Einzelne Challonge-Turnierlinks oder numerische Turnier-IDs eingeben.',
          );
        }
        final parts = uri.pathSegments
            .where((p) => !['de', 'en', 'fr', 'es', 'pt', 'ja'].contains(p))
            .toList();
        if (parts.isEmpty) throw const FormatException('Turnierkennung fehlt.');
        identifier = uri.host == 'challonge.com'
            ? parts.first
            : '${uri.host.split('.').first}-${parts.first}';
      }
      tournaments.add(await _client.tournament(_key.text, identifier));
    }
    if (tournaments.isEmpty) {
      throw const FormatException(
        'Turniere auswählen oder Turnierlinks eingeben.',
      );
    }
    await _prepare(tournaments);
  });
  Future<void> _file() => _work(() async {
    final file = await openFile(
      acceptedTypeGroups: [
        const XTypeGroup(
          label: 'Challonge Turnierdaten',
          extensions: ['json', 'html', 'htm'],
        ),
      ],
    );
    if (file != null) {
      await _prepare(
        ChallongePublicReader.decodeDocument(await file.readAsString()),
      );
    }
  });
  Future<void> _import() => _work(() async {
    await widget.repository.access.require(
      widget.community.id,
      CommunityPermission.createTournaments,
    );
    final service = ChallongeImportService(
      authorizeMemberCreation: () async {
        if (Supabase.instance.client.auth.currentUser?.id !=
            widget.community.ownerUserId) {
          throw StateError(
            'Neue Mitglieder kann nur der Community-Eigentümer anlegen. Bitte alle Spieler vorhandenen Mitgliedern zuordnen oder als Eigentümer importieren.',
          );
        }
      },
      loadMembers: () => widget.repository.loadMembers(widget.community.id),
      createMember: (name) {
        if (Supabase.instance.client.auth.currentUser?.id !=
            widget.community.ownerUserId) {
          throw StateError(
            'Neue Mitglieder kann nur der Community-Eigentümer anlegen. Bitte alle Spieler vorhandenen Mitgliedern zuordnen oder als Eigentümer importieren.',
          );
        }
        return widget.repository.createManualMember(widget.community.id, name);
      },
      loadTournaments: () async => [
        ...await widget.repository.loadTournaments(widget.community.id),
        ...await _storage.loadTournaments(),
      ],
      saveTournament: (t) => _storage.saveTournament(t),
    );
    final count = await service.import(
      widget.community.id,
      _preview,
      assignments: _assignments,
      progress: (s) {
        if (mounted) setState(() => _status = s);
      },
    );
    await _storage.synchronize();
    await _prepare(_preview);
    if (mounted) {
      setState(
        () => _status =
            '$count Turniere lokal übernommen. ${TournamentStorage.syncStatus.value}',
      );
    }
  });
  @override
  Widget build(BuildContext context) {
    final pending = _preview
        .where((t) => !_existing.contains(t.tournamentId(widget.community.id)))
        .toList();
    final names = {
      for (final t in pending)
        for (final p in t.participants)
          ChallongeTournament.normalizedName(ChallongeTournament.name(p)):
              ChallongeTournament.name(p),
    };
    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Challonge importieren'),
          automaticallyImplyLeading: !_busy,
        ),
        body: AdaptiveContentList(
          children: [
            Text(
              widget.community.name,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const Text(
              'Abgeschlossene Turniere mit Originalergebnissen und Platzierungen übernehmen. Fehlende Spieler werden als Mitglieder ohne Benutzerkonto angelegt. Vorhandene Mitglieder mit eindeutig gleichem Namen werden wiederverwendet. Neue Mitglieder kann derzeit nur der Community-Eigentümer anlegen.',
            ),
            const SizedBox(height: 16),
            const Text(
              'Öffentliche Community- oder Turnierlinks verwenden. Dafür ist kein API-Schlüssel nötig. Geschützte Seiten oder unvollständige öffentliche Daten können nicht automatisch importiert werden.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _community,
              enabled: !_busy,
              decoration: const InputDecoration(
                labelText: 'Community / Subdomain',
                helperText:
                    'Ohne API-Schlüssel einen vollständigen öffentlichen Community-Link eingeben.',
                helperMaxLines: 3,
              ),
            ),
            const SizedBox(height: 16),
            ExpansionTile(
              title: const Text('Optional: Zugang über API-Schlüssel'),
              children: [
                TextField(
                  controller: _key,
                  enabled: !_busy,
                  obscureText: true,
                  enableSuggestions: false,
                  autocorrect: false,
                  decoration: const InputDecoration(
                    labelText: 'API-Schlüssel',
                    helperText:
                        'Nur für den API-Zugang. Wird nicht gespeichert.',
                    helperMaxLines: 2,
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton(
                  onPressed: _busy ? null : _load,
                  child: const Text('Turniere laden'),
                ),
                OutlinedButton(
                  onPressed: _busy ? null : _file,
                  child: const Text('Turnierdatei öffnen'),
                ),
              ],
            ),
            if (_list.isNotEmpty)
              TextButton(
                onPressed: _busy
                    ? null
                    : () => setState(() {
                        if (_selected.length == _list.length) {
                          _selected.clear();
                        } else {
                          _selected.addAll(_list.map((t) => '${t['id']}'));
                        }
                      }),
                child: Text(
                  _selected.length == _list.length
                      ? 'Auswahl aufheben'
                      : 'Alle Turniere auswählen',
                ),
              ),
            for (final t in _list)
              CheckboxListTile(
                value: _selected.contains('${t['id']}'),
                title: Text('${t['name']}'),
                onChanged: _busy
                    ? null
                    : (v) => setState(() {
                        if (v!) {
                          _selected.add('${t['id']}');
                        } else {
                          _selected.remove('${t['id']}');
                        }
                      }),
              ),
            const SizedBox(height: 16),
            TextField(
              controller: _links,
              key: const ValueKey('challonge-links'),
              enabled: !_busy,
              minLines: 2,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Turnierlinks / IDs',
                helperText:
                    'Ohne Schlüssel: vollständige HTTPS-Turnierlinks. Mehrere Links durch neue Zeilen trennen.',
                helperMaxLines: 2,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _busy ? null : _previewSelected,
              child: const Text('Importvorschau laden'),
            ),
            if (_preview.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('Vorschau', style: Theme.of(context).textTheme.titleLarge),
              for (final t in _preview)
                ListTile(
                  title: Text(t.title),
                  subtitle: Text(
                    _existing.contains(t.tournamentId(widget.community.id))
                        ? 'Bereits importiert – wird übersprungen'
                        : '${t.participants.length} Teilnehmer · ${t.matches.length} Spiele · ${t.participants.where((p) => p['final_rank'] != null).length} Platzierungen',
                  ),
                ),
              for (final entry in names.entries)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: DropdownButtonFormField<String>(
                    key: ValueKey('$_revision:${entry.key}'),
                    initialValue: _assignments[entry.key] ?? '',
                    isExpanded: true,
                    itemHeight: null,
                    decoration: InputDecoration(labelText: entry.value),
                    items: [
                      DropdownMenuItem(
                        value: '',
                        child: Text(switch (ChallongeImportService.matching(
                          entry.value,
                          _members,
                        ).length) {
                          0 => 'Neues Mitglied automatisch anlegen',
                          1 =>
                            'Automatisch: ${ChallongeImportService.matching(entry.value, _members).single.displayName}',
                          _ => 'Mehrere Treffer – Mitglied auswählen',
                        }),
                      ),
                      for (final m in _members.where(
                        (m) => m.playerProfileId != null,
                      ))
                        DropdownMenuItem(
                          value: m.playerProfileId,
                          child: Text(m.displayName),
                        ),
                    ],
                    onChanged: _busy
                        ? null
                        : (id) => setState(() {
                            if (id == '') {
                              _assignments.remove(entry.key);
                            } else {
                              _assignments[entry.key] = id!;
                            }
                          }),
                  ),
                ),
              const Text(
                'Einzelne ganzzahlige Ergebnisse werden als Legs übernommen. Mehrteilige Ergebnisse und kampflose Siege bleiben im Archiv erhalten. Der Import zählt zunächst nicht für Elo oder Community-Ranglisten.',
              ),
              FilledButton.icon(
                onPressed: _busy || pending.isEmpty ? null : _import,
                icon: const Icon(Icons.file_download_outlined),
                label: Text(
                  '${pending.length} Turniere und fehlende Mitglieder importieren',
                ),
              ),
            ],
            if (_busy) const LinearProgressIndicator(),
            if (_status != null) Text(_status!),
            if (_error != null)
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ),
      ),
    );
  }
}
