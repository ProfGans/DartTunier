import '../../tournaments/domain/tournament_access.dart';
import '../../tournaments/data/tournament_access_repository.dart';
import '../../tournaments/presentation/widgets/tournament_access_gate.dart';
import '../../tournaments/presentation/widgets/creation/tournament_access_editor.dart';
import '../data/league_result_repository.dart';
import '../../../shared/widgets/sport_settings_section.dart';
import 'package:flutter/material.dart';
import '../../tournaments/application/tournament_timing.dart';
import '../../tournaments/presentation/widgets/run/tournament_timing_panel.dart';
import '../../devices/application/board_device_dispatcher.dart';
import '../../devices/application/device_result_importer.dart';
import '../../devices/presentation/board_device_assignment_page.dart';
import '../../devices/presentation/devices_scope.dart';
import '../../tournaments/application/order_of_play/order_of_play_controller.dart';
import '../../tournaments/presentation/widgets/creation/tournament_devices_section.dart';
import '../application/league_board_runtime.dart';
import 'league_overview.dart';
import 'league_player_picker.dart';
import '../data/league_invitation_repository.dart';
import '../../tournaments/data/app_database.dart';
import '../../../shared/widgets/adaptive_content.dart';
import '../../tournaments/data/tournament_storage.dart';
import '../../tournaments/domain/tournament_models.dart';
import '../../communities/domain/community_permissions.dart';
import '../../communities/presentation/widgets/community_permission_gate.dart';
import '../domain/league_match.dart';
import 'league_pairing_dialog.dart';
import '../../statistics/domain/tournament_player_statistics.dart';
import '../../statistics/presentation/tournament_statistics_view.dart';
import '../../statistics/presentation/tournament_highlights_page.dart';
import '../../statistics/domain/match_scorer_summary.dart';

class LeagueMatchPage extends StatefulWidget {
  const LeagueMatchPage({
    super.key,
    this.tournament,
    this.communityId,
    this.storage,
    this.invitations,
    this.database,
    this.openDevicesOnStart = false,
    this.loadAccess,
  });
  final bool openDevicesOnStart;
  final Future<TournamentAccess> Function()? loadAccess;
  final LeagueInvitationRepository? invitations;
  final LocalAppDatabase? database;
  final CreatedTournament? tournament;
  final String? communityId;
  final TournamentStorage? storage;
  @override
  State<LeagueMatchPage> createState() => _LeagueMatchPageState();
}

class _LeagueMatchPageState extends State<LeagueMatchPage> {
  TournamentAccess _access = const TournamentAccess();
  TournamentAccessSettings _settings = const TournamentAccessSettings();
  bool _devicesOpened = false;
  final _form = GlobalKey<FormState>();
  final _rosterSections = List.generate(
    2,
    (_) => GlobalKey<SportSettingsSectionState>(),
  );
  final _name = TextEditingController(text: 'Ligaspiel');
  final _teams = [
    TextEditingController(text: 'Heim'),
    TextEditingController(text: 'Gast'),
  ];
  final _rosters = List.generate(
    2,
    (team) => List.generate(
      4,
      (i) => TextEditingController(
        text: '${team == 0 ? 'Heim' : 'Gast'} ${i + 1}',
      ),
    ),
  );
  late final _storage = widget.storage ?? TournamentStorage();
  late CreatedTournament? _tournament = widget.tournament;
  bool _busy = false;
  String? _error;
  late final _invitations = widget.invitations ?? LeagueInvitationRepository();
  final _draftId = CreatedTournament(
    name: '',
    players: [],
    stages: [],
    runStages: [],
  ).id;
  final _profiles = <String, TournamentPlayer>{};
  final _invited = <String, Map<String, dynamic>>{};

  Future<void> _addRosterPlayer(int team, bool community) async {
    final slot = await showDialog<int>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text('${_teams[team].text}: Aufstellungsplatz wählen'),
        children: [
          for (var i = 0; i < _rosters[team].length; i++)
            SimpleDialogOption(
              onPressed: _invited.containsKey('$team:$i')
                  ? null
                  : () => Navigator.pop(context, i),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  '${i < 4
                      ? 'Stammspieler ${i + 1}'
                      : i < 8
                      ? 'Ersatzspieler ${i - 3}'
                      : 'Aushilfe'} · ${_rosters[team][i].text}',
                ),
              ),
            ),
          if (_rosters[team].length < 9)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, _rosters[team].length),
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('Neuen Ersatz-/Aushilfsplatz hinzufügen'),
              ),
            ),
        ],
      ),
    );
    if (!mounted || slot == null) return;
    final newSlot = slot == _rosters[team].length;
    if (newSlot) setState(() => _rosters[team].add(TextEditingController()));
    await _selectPlayer(team, slot, community: community);
    if (mounted &&
        newSlot &&
        !_profiles.containsKey('$team:$slot') &&
        !_invited.containsKey('$team:$slot')) {
      setState(() => _rosters[team].removeLast().dispose());
    }
  }

  Future<void> _selectPlayer(
    int team,
    int slot, {
    bool community = false,
  }) async {
    final key = '$team:$slot';
    final choice = await showDialog<LeaguePlayerChoice>(
      context: context,
      builder: (_) => LeaguePlayerPicker(
        initialCommunity: community,
        repository: _invitations,
        database: widget.database,
      ),
    );
    if (!mounted || choice == null) return;
    if (_profiles.entries.any(
          (e) => e.key != key && e.value.profileId == choice.player.profileId,
        ) ||
        _invited.entries.any(
          (e) =>
              e.key != key &&
              e.value['user_id'] == choice.inviteUserId &&
              choice.inviteUserId != null,
        )) {
      setState(
        () => _error =
            'Dieser Spieler ist bereits in einer Mannschaft vorgesehen.',
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (choice.inviteUserId != null) {
        final row = await _invitations.invite(
          _draftId,
          _name.text.trim().isEmpty ? 'Ligaspiel' : _name.text.trim(),
          team,
          slot,
          choice.inviteUserId!,
        );
        if (!mounted) return;
        setState(() {
          _invited[key] = row;
          _profiles.remove(key);
        });
      } else {
        setState(() {
          _profiles[key] = choice.player;
          _rosters[team][slot].text = choice.player.name;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Einladung konnte nicht gesendet werden. Verbindung und Servereinrichtung prüfen.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _refreshInvitations() async {
    if (_invited.isEmpty) return;
    final rows = await _invitations.status(_draftId);
    if (!mounted) return;
    setState(() {
      for (final row in rows) {
        final key = '${row['team']}:${row['slot']}';
        if (!_invited.containsKey(key)) continue;
        _invited[key] = row;
        if (row['status'] == 'accepted') {
          final player = TournamentPlayer(
            name: row['display_name'] as String,
            profileId: row['user_id'] as String,
            isGenerated: false,
          );
          _profiles[key] = player;
          _rosters[row['team'] as int][row['slot'] as int].text = player.name;
        }
      }
    });
  }

  Future<void> _cancelInvitation(String key) async {
    setState(() => _busy = true);
    try {
      await _invitations.cancel(_invited[key]!['id'] as String);
      if (mounted) {
        setState(() {
          _invited.remove(key);
          _profiles.remove(key);
          final position = key.split(':').map(int.parse).toList();
          _rosters[position[0]][position[1]].text = '';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Einladung konnte nicht zurückgezogen werden.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  BoardDeviceDispatcher? _dispatcher;
  int _boards = 1;
  Future<void> _results = Future.value();

  Future<void> _openDevices() async {
    final devices = DevicesScope.maybeOf(context);
    if (devices == null || _tournament == null || !_access.canLead) return;
    await TournamentAccessRepository().requireLead(_tournament!);
    _dispatcher ??= BoardDeviceDispatcher(
      devices: devices,
      tournament: LeagueBoardRuntime(_tournament!).tournament,
      activeStage: () => 0,
      onResult: (result) {
        final operation = _results.then((_) async {
          if (!mounted || _busy) {
            throw StateError(
              'Ligaänderung wird gespeichert. Bitte erneut versuchen.',
            );
          }
          final next = CreatedTournament.fromJson(_tournament!.toJson());
          final runtime = LeagueBoardRuntime(next);
          const importer = DeviceResultImporter();
          final match = importer.validate(runtime.tournament, result);
          importer.apply(
            match,
            result,
            runtime.tournament.stages.single.gameFormat,
          );
          runtime.writeTo(next);
          await _save(next, rethrowError: true);
        });
        _results = operation.then<void>(
          (_) {},
          onError: (Object _, StackTrace _) {},
        );
        return operation;
      },
    );
    try {
      await _dispatcher!.start();
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => BoardDeviceAssignmentPage(dispatcher: _dispatcher!),
        ),
      );
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Geräte konnten nicht geöffnet werden. Verbindung und Berechtigung prüfen.',
        );
      }
    }
  }

  Future<void> _startGame(int index) async {
    var next = CreatedTournament.fromJson(_tournament!.toJson());
    var runtime = LeagueBoardRuntime(next);
    final board = await showDialog<int>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Spiel auf Board starten'),
        children: [
          for (var b = 1; b <= next.boardCount; b++)
            SimpleDialogOption(
              onPressed:
                  runtime.schedule.running.any((e) => e.match.boardNumber == b)
                  ? null
                  : () => Navigator.pop(context, b),
              child: Text('Board $b'),
            ),
        ],
      ),
    );
    if (!mounted || board == null) return;
    next = CreatedTournament.fromJson(_tournament!.toJson());
    runtime = LeagueBoardRuntime(next);
    if (!const OrderOfPlayController().start(
      runtime.tournament,
      0,
      runtime.matches[index],
      board,
    )) {
      setState(
        () => _error =
            'Board oder Spieler sind bereits in einem laufenden Spiel.',
      );
      return;
    }
    runtime.writeTo(next);
    await _save(next);
    await _dispatcher?.publish();
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _dispatcher?.dispose();
    for (final c in [_name, ..._teams, ..._rosters.expand((r) => r)]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save(
    CreatedTournament next, {
    bool rethrowError = false,
  }) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_tournament != null) {
        await TournamentAccessRepository().requireLead(_tournament!);
      }
      await TournamentTiming.prepare(next);
      await _storage.saveTournament(next);
      if (mounted) setState(() => _tournament = next);
      if (_dispatcher != null) {
        _dispatcher!.tournament = LeagueBoardRuntime(next).tournament;
      }
      if (next.communityId != null) {
        await _storage.synchronize(tournamentId: next.id);
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Speichern fehlgeschlagen. Bitte erneut versuchen.',
        );
      }
      if (rethrowError) rethrow;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _create() async {
    if (_busy) return;
    if (!_form.currentState!.validate()) {
      for (final section in _rosterSections) {
        section.currentState?.expand();
      }
      return;
    }
    try {
      await _refreshInvitations();
      if (!mounted) return;
      if (_invited.values.any((row) => row['status'] != 'accepted')) {
        setState(
          () => _error =
              'Alle Einladungen müssen angenommen oder zurückgezogen werden.',
        );
        return;
      }
      if (_invited.isNotEmpty) await _invitations.close(_draftId);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Einladungsstatus konnte nicht geprüft werden. Verbindung prüfen.',
        );
      }
      return;
    }
    if (!mounted) return;
    if (!_form.currentState!.validate()) return;
    final league = LeagueMatch.rhl(
      homeTeam: _teams[0].text,
      awayTeam: _teams[1].text,
      homePlayers: _rosters[0].map((c) => c.text).toList(),
      awayPlayers: _rosters[1].map((c) => c.text).toList(),
    );
    await _save(
      CreatedTournament(
        id: _draftId,
        name: _name.text.trim(),
        players: [
          for (var team = 0; team < 2; team++)
            for (var slot = 0; slot < _rosters[team].length; slot++)
              _profiles['$team:$slot'] ??
                  TournamentPlayer(
                    name: _rosters[team][slot].text.trim(),
                    isGenerated: false,
                  ),
        ],
        stages: [],
        runStages: [],
        leagueMatch: league,
        communityId: widget.communityId,
        access: _settings.withCreator(_storage.currentUserId),
        boardCount: _boards,
      ),
    );
  }

  Future<void> _result(int index) async {
    if (!_access.canEnterResults ||
        (!_access.canLead && _tournament!.leagueMatch!.games[index].complete)) {
      return;
    }
    final result = await showDialog<(int?, int?)>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ergebnis · Best of 5'),
        content: SingleChildScrollView(
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final score in [
                (3, 0),
                (3, 1),
                (3, 2),
                (0, 3),
                (1, 3),
                (2, 3),
              ])
                OutlinedButton(
                  onPressed: () => Navigator.pop(context, score),
                  child: Text('${score.$1}:${score.$2}'),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Abbrechen'),
          ),
          if (_access.canLead)
            TextButton(
              onPressed: () => Navigator.pop(context, (null, null)),
              child: const Text('Ergebnis entfernen'),
            ),
        ],
      ),
    );
    if (!mounted || result == null) return;
    if (!_access.canLead) {
      setState(() => _busy = true);
      try {
        final next = await LeagueResultRepository().submit(
          _tournament!,
          index,
          result.$1!,
          result.$2!,
        );
        if (mounted) {
          setState(() {
            _tournament = next;
            _error = null;
          });
        }
      } catch (_) {
        if (mounted) {
          setState(
            () => _error =
                'Ergebnis nicht gespeichert. Online-Stand und Berechtigung prüfen.',
          );
        }
      } finally {
        if (mounted) setState(() => _busy = false);
      }
      return;
    }
    final next = CreatedTournament.fromJson(_tournament!.toJson());
    next.leagueMatch!.games[index].score(result.$1, result.$2);
    final runtime = LeagueBoardRuntime(next);
    runtime.matches[index].deviceResult = null;
    const OrderOfPlayController().resultRecorded(runtime.matches[index]);
    runtime.writeTo(next);
    await _save(next);
    await _dispatcher?.publish();
  }

  Future<void> _pairing(int index) async {
    final next = CreatedTournament.fromJson(_tournament!.toJson());
    final league = next.leagueMatch!;
    final changed = await showDialog<bool>(
      context: context,
      builder: (_) => LeaguePairingDialog(league: league, index: index),
    );
    if (changed == true && mounted) await _save(next);
  }

  Future<void> _move(int index, int delta) async {
    final next = CreatedTournament.fromJson(_tournament!.toJson());
    final games = next.leagueMatch!.games;
    games.insert(index + delta, games.removeAt(index));
    await _save(next);
  }

  Future<void> _reload() async {
    if (_busy) return;
    if (_access.canLead) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Online-Stand laden?'),
          content: const Text(
            'Nicht synchronisierte lokale Änderungen werden durch den Online-Stand ersetzt.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Abbrechen'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Online-Stand laden'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    setState(() => _busy = true);
    try {
      final next = await _storage.loadAuthoritativeTournament(
        _tournament!.id,
        _tournament!.communityId!,
      );
      if (mounted) {
        setState(() {
          _tournament = next;
          _error = null;
        });
      }
      if (_dispatcher != null) {
        _dispatcher!.tournament = LeagueBoardRuntime(next).tournament;
        await _dispatcher!.publish();
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Online-Stand konnte nicht geladen werden.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _editAccess() async {
    if (!_access.canConfigure || _busy) return;
    var value = _tournament!.access;
    final selected = await showDialog<TournamentAccessSettings>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: const Text('Turnierrechte'),
          scrollable: true,
          content: SizedBox(
            width: 620,
            child: TournamentAccessEditor(
              communityId: _tournament!.communityId!,
              value: value,
              onChanged: (next) => update(() => value = next),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Abbrechen'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, value),
              child: const Text('Speichern'),
            ),
          ],
        ),
      ),
    );
    if (selected == null || !mounted) return;
    setState(() => _busy = true);
    try {
      await TournamentAccessRepository().requireConfigure(_tournament!);
      final next = CreatedTournament.fromJson(_tournament!.toJson())
        ..access = selected;
      await _storage.saveTournament(next);
      if (mounted) setState(() => _tournament = next);
      await _storage.synchronize(tournamentId: next.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(TournamentStorage.syncStatus.value)),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Turnierrechte konnten nicht gespeichert werden.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_tournament == null) {
      return CommunityPermissionGate(
        communityId: widget.communityId,
        permission: CommunityPermission.createTournaments,
        builder: (context) => _content(context),
      );
    }
    return TournamentAccessGate(
      tournament: _tournament!,
      load: widget.loadAccess,
      builder: (context, access) {
        _access = access;
        if (access.canLead && widget.openDevicesOnStart && !_devicesOpened) {
          _devicesOpened = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _openDevices();
          });
        }
        return _content(context);
      },
    );
  }

  Widget _content(BuildContext context) => PopScope(
    canPop: !_busy,
    child: Scaffold(
      appBar: AppBar(
        title: Text(
          _tournament == null ? 'Neues Ligaspiel' : _tournament!.name,
        ),
      ),
      body: AdaptiveContentList(
        children: [
          const Text(
            '16 Einzel und 2 Doppel · 501 Single In / Double Out · Best of 5 Legs',
          ),
          const SizedBox(height: 12),
          if (_tournament == null)
            const Text(
              'Bearbeitbarer Standardplan: vier Heimspieler gegen vier Gastspieler, danach zwei Doppel. '
              'Reihenfolge und Aufstellungen vor der Ergebniseingabe mit dem offiziellen Spielbericht abgleichen.',
            ),
          const SizedBox(height: 16),
          if (_error != null)
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          if (_tournament == null) _setup(context) else ..._games(context),
        ],
      ),
    ),
  );

  Widget _setup(BuildContext context) => Form(
    key: _form,
    child: Column(
      children: [
        TextFormField(
          key: const ValueKey('league-name'),
          controller: _name,
          maxLength: 200,
          decoration: const InputDecoration(
            labelText: 'Name des Ligaspiels',
            hintText: 'Zum Beispiel: Vereinsliga · 3. Spieltag',
          ),
          validator: _required,
        ),
        const SizedBox(height: 16),
        const SportSettingsSection(
          title: 'Geräte zuordnen',
          summary: 'Boards und Anzeigen verbinden · optional',
          icon: Icons.devices_outlined,
          children: [TournamentDevicesSection()],
        ),
        _boardControls(),
        AdaptiveTileLayout(
          children: [
            for (var team = 0; team < 2; team++)
              SportSettingsSection(
                key: _rosterSections[team],
                title: team == 0
                    ? 'Heimteam & Aufstellung'
                    : 'Gastteam & Aufstellung',
                summary:
                    '${_teams[team].text} · ${_rosters[team].length} Spielerplätze',
                icon: Icons.groups_outlined,
                children: [
                  TextFormField(
                    controller: _teams[team],
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: team == 0
                          ? 'Heimmannschaft'
                          : 'Gastmannschaft',
                    ),
                    validator: _required,
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _busy
                            ? null
                            : () => _addRosterPlayer(team, false),
                        icon: const Icon(Icons.person_add),
                        label: const Text('Lokalen Spieler hinzufügen'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _busy
                            ? null
                            : () => _addRosterPlayer(team, true),
                        icon: const Icon(Icons.mail_outline),
                        label: const Text('Community-Mitglied einladen'),
                      ),
                    ],
                  ),
                  for (var i = 0; i < _rosters[team].length; i++)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: TextFormField(
                        controller: _rosters[team][i],
                        readOnly: _invited.containsKey('$team:$i'),
                        onChanged: (_) => _profiles.remove('$team:$i'),
                        validator: _required,
                        decoration: InputDecoration(
                          suffixIcon: IconButton(
                            tooltip: 'Spieler auswählen oder einladen',
                            onPressed: _busy || _invited.containsKey('$team:$i')
                                ? null
                                : () => _selectPlayer(team, i),
                            icon: const Icon(Icons.person_add_alt),
                          ),
                          labelText: i < 4
                              ? 'Stammspieler ${i + 1}'
                              : i < 8
                              ? 'Ersatzspieler ${i - 3}'
                              : 'Aushilfe aus unterklassiger Vereinsmannschaft',
                        ),
                      ),
                    ),
                  for (var i = 0; i < _rosters[team].length; i++)
                    if (_invited['$team:$i'] case final row?)
                      ListTile(
                        title: Text('${row['display_name']} · Platz ${i + 1}'),
                        subtitle: Text(switch (row['status']) {
                          'accepted' => 'Angenommen',
                          'declined' => 'Abgelehnt',
                          _ => 'Einladung ausstehend',
                        }),
                        trailing: IconButton(
                          tooltip: 'Einladung zurückziehen',
                          onPressed: _busy
                              ? null
                              : () => _cancelInvitation('$team:$i'),
                          icon: const Icon(Icons.close),
                        ),
                      ),
                  const SizedBox(height: 12),
                  if (_rosters[team].length < 9)
                    TextButton.icon(
                      onPressed: _busy
                          ? null
                          : () => setState(
                              () => _rosters[team].add(TextEditingController()),
                            ),
                      icon: const Icon(Icons.person_add),
                      label: Text(
                        _rosters[team].length < 8
                            ? 'Ersatzspieler hinzufügen'
                            : 'Aushilfe hinzufügen',
                      ),
                    ),
                ],
              ),
          ],
        ),
        const SizedBox(height: 16),
        if (_invited.isNotEmpty)
          OutlinedButton.icon(
            onPressed: _busy
                ? null
                : () async {
                    try {
                      await _refreshInvitations();
                    } catch (_) {
                      if (mounted) {
                        setState(
                          () => _error =
                              'Einladungen konnten nicht aktualisiert werden.',
                        );
                      }
                    }
                  },
            icon: const Icon(Icons.refresh),
            label: const Text('Einladungen aktualisieren'),
          ),
        if (widget.communityId != null)
          TournamentAccessEditor(
            communityId: widget.communityId!,
            value: _settings,
            onChanged: (value) => setState(() => _settings = value),
          ),
        FilledButton(
          onPressed: _busy ? null : _create,
          child: const Text('Ligaspiel anlegen'),
        ),
      ],
    ),
  );

  String? _required(String? text) =>
      text == null || text.trim().isEmpty ? 'Bitte Namen eingeben.' : null;

  Widget _boardControls() {
    final count = _tournament?.boardCount ?? _boards;
    final running =
        _tournament?.leagueMatch?.games.any(
          (g) => !g.complete && g.runtime?['startedAt'] != null,
        ) ??
        false;
    Future<void> change(int value) async {
      if (_tournament == null) {
        setState(() => _boards = value);
        return;
      }
      final next = CreatedTournament.fromJson(_tournament!.toJson())
        ..boardCount = value;
      await _save(next);
      await _dispatcher?.publish();
    }

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 12,
      children: [
        Text('$count Boards'),
        IconButton(
          tooltip: 'Weniger Boards',
          onPressed: _busy || running || count <= 1
              ? null
              : () => change(count - 1),
          icon: const Icon(Icons.remove),
        ),
        IconButton(
          tooltip: 'Mehr Boards',
          onPressed: _busy || running || count >= 64
              ? null
              : () => change(count + 1),
          icon: const Icon(Icons.add),
        ),
      ],
    );
  }

  List<Widget> _games(BuildContext context) {
    final league = _tournament!.leagueMatch!;
    return [
      if (_tournament!.communityId != null) ...[
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: _busy ? null : _reload,
              icon: const Icon(Icons.refresh),
              label: const Text('Online-Stand laden'),
            ),
            if (_access.canConfigure)
              OutlinedButton.icon(
                onPressed: _busy ? null : _editAccess,
                icon: const Icon(Icons.admin_panel_settings_outlined),
                label: const Text('Turnierrechte'),
              ),
          ],
        ),
        if (_access.canLead)
          ValueListenableBuilder<String>(
            valueListenable: TournamentStorage.syncStatus,
            builder: (_, status, _) => Text(status),
          ),
        if (!_access.canLead)
          Text(
            _access.canEnterResults
                ? 'Offene Ergebnisse kannst du online melden. Korrekturen übernimmt die Turnierleitung.'
                : 'Zuschaueransicht',
          ),
      ],
      if (_access.canLead)
        TournamentTimingPanel(
          tournament: _tournament!,
          onStart: () async {
            final next = CreatedTournament.fromJson(_tournament!.toJson());
            next.startedAt ??= DateTime.now();
            await _save(next, rethrowError: true);
          },
        ),
      LeagueOverview(league: league),
      TournamentHighlightsButton(tournament: _tournament!),
      if (_access.canLead)
        ExpansionTile(
          title: const Text('Boards und Geräte'),
          leading: const Icon(Icons.connected_tv),
          children: [
            _boardControls(),
            const TournamentDevicesSection(),
            OutlinedButton.icon(
              onPressed: _busy || DevicesScope.maybeOf(context) == null
                  ? null
                  : _openDevices,
              icon: const Icon(Icons.connected_tv),
              label: const Text('Boards und Geräte zuordnen'),
            ),
          ],
        ),
      Align(
        alignment: Alignment.centerLeft,
        child: OutlinedButton.icon(
          icon: const Icon(Icons.bar_chart),
          label: const Text('Statistik'),
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (context) => Scaffold(
                appBar: AppBar(title: const Text('Ligastatistik')),
                body: TournamentStatisticsView(
                  rows: const TournamentStatisticsCalculator().calculate([
                    _tournament!,
                  ]),
                  description:
                      'Einzel und Doppel aus gespeicherten Ergebnissen. Beide Doppelpartner erhalten das gemeinsame Ergebnis und die gemeinsamen Legs. Korrekturen werden neu berechnet.',
                ),
              ),
            ),
          ),
        ),
      ),
      const Text(
        'Jedes gewonnene Match zählt einen Mannschaftspunkt. 9:9 ist ein Unentschieden.',
      ),
      for (var i = 0; i < league.games.length; i++)
        LeagueFixtureCard(
          league: league,
          index: i,
          averageLabel: MatchScorerSummary.fromMatch(
            LeagueBoardRuntime(_tournament!).matches[i],
          )?.averageLabel,
          boardLabel: league.games[i].runtime?['boardNumber'] == null
              ? null
              : 'Board ${league.games[i].runtime!['boardNumber']}',
          actions: [
            if (_access.canLead &&
                !league.games[i].complete &&
                league.games[i].runtime?['startedAt'] == null)
              OutlinedButton.icon(
                onPressed: _busy ? null : () => _startGame(i),
                icon: const Icon(Icons.play_arrow),
                label: const Text('Starten'),
              ),
            if (_access.canEnterResults &&
                (_access.canLead || !league.games[i].complete))
              OutlinedButton(
                key: ValueKey('league-result-$i'),
                onPressed: _busy ? null : () => _result(i),
                child: const Text('Ergebnis'),
              ),
            if (_access.canLead &&
                !league.games[i].complete &&
                league.games[i].runtime?['startedAt'] == null)
              OutlinedButton(
                onPressed: _busy ? null : () => _pairing(i),
                child: const Text('Aufstellung'),
              ),
            if (_access.canLead &&
                league.games.every(
                  (g) => !g.complete && g.runtime?['startedAt'] == null,
                )) ...[
              IconButton(
                tooltip: 'Spiel nach oben',
                onPressed: _busy || i == 0 ? null : () => _move(i, -1),
                icon: const Icon(Icons.arrow_upward),
              ),
              IconButton(
                tooltip: 'Spiel nach unten',
                onPressed: _busy || i == 17 ? null : () => _move(i, 1),
                icon: const Icon(Icons.arrow_downward),
              ),
            ],
          ],
        ),
    ];
  }
}
