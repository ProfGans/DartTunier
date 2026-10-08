import 'dart:async';
import 'package:flutter/material.dart';
import '../../../application/tournament_director_snapshot.dart';
import '../../../application/tournament_timing.dart';
import '../../../application/order_of_play/order_of_play_controller.dart';
import '../../../domain/tournament_models.dart';
import '../../../../devices/application/board_device_dispatcher.dart';
import '../../../../../shared/widgets/paged_entries.dart';

/// Embedded in the run page: navigation and device dispatch keep their lifetime.
class TournamentDirectorDashboard extends StatefulWidget {
  const TournamentDirectorDashboard({
    super.key,
    required this.tournament,
    required this.activeStage,
    required this.onChange,
    required this.onResult,
    required this.onBlock,
    required this.onDevices,
    required this.onSync,
    required this.syncStatus,
    this.dispatcher,
    this.saveError,
    this.canOperate = true,
  });
  final CreatedTournament tournament;
  final int activeStage;
  final Future<void> Function() onChange, onDevices, onSync;
  final Future<void> Function(GroupMatch) onResult;
  final Future<void> Function(int) onBlock;
  final ValueNotifier<String> syncStatus;
  final BoardDeviceDispatcher? dispatcher;
  final String? saveError;
  final bool canOperate;
  @override
  State<TournamentDirectorDashboard> createState() =>
      _TournamentDirectorDashboardState();
}

class _TournamentDirectorDashboardState
    extends State<TournamentDirectorDashboard> {
  Timer? _timer;
  final _search = TextEditingController();
  int _section = 0;
  bool _busy = false;
  String? _actionError;
  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _act(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _actionError = null;
    });
    try {
      await action();
    } catch (_) {
      if (mounted) {
        setState(
          () => _actionError =
              'Aktion fehlgeschlagen. Verbindung und Berechtigung prüfen und erneut versuchen.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _title(String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Text(text, style: Theme.of(context).textTheme.titleLarge),
  );
  Widget _box(List<Widget> children) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    ),
  );
  Widget _button(
    String label,
    VoidCallback? action, {
    IconData icon = Icons.arrow_forward,
  }) => OutlinedButton.icon(
    style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
    onPressed: _busy ? null : action,
    icon: Icon(icon),
    label: Text(label),
  );
  String _pair(PlayEntry e) =>
      '${e.match.homePlayer?.name ?? 'Noch offen'} – ${e.match.awayPlayer?.name ?? 'Noch offen'}';
  String _duration(Duration d) =>
      '${d.inHours} h ${d.inMinutes.remainder(60)} min';
  String _clock(DateTime t) =>
      '${t.toLocal().hour.toString().padLeft(2, '0')}:${t.toLocal().minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: Listenable.merge([
      widget.syncStatus,
      if (widget.dispatcher != null) widget.dispatcher!,
    ]),
    builder: (context, _) => _build(context),
  );

  Widget _build(BuildContext context) {
    final t = widget.tournament;
    final state = TournamentDirectorSnapshot(t, widget.activeStage);
    final now = DateTime.now();
    final timing = TournamentTiming.snapshot(t, now);
    final active = state.entries
        .where((e) => e.stageIndex == widget.activeStage && e.match.hasPlayers)
        .toList();
    final completed = active.where((e) => e.match.isResolved).length;
    final connections =
        widget.dispatcher?.connections ?? <int, BoardDeviceConnection>{};
    final failures = connections.entries
        .where((e) => e.value.status.startsWith('Übertragung fehlgeschlagen'))
        .toList();
    final waiting = state.schedule.waiting
        .where((e) => e.stageIndex == widget.activeStage && !e.match.isResolved)
        .length;
    final operational =
        widget.canOperate &&
        !_busy &&
        !t.completedStageIndexes.contains(widget.activeStage);
    Widget start(PlayEntry entry, {int? board}) => PopupMenuButton<int>(
      tooltip: 'Spiel starten oder vorziehen',
      enabled:
          operational &&
          state.canStart(entry) &&
          (board == null || state.freeBoards.contains(board)),
      itemBuilder: (_) => [
        for (final b in state.freeBoards)
          if (board == null || b == board)
            PopupMenuItem(value: b, child: Text('Auf Board $b starten')),
      ],
      onSelected: (b) => _act(() async {
        if (!const OrderOfPlayController().start(
          t,
          widget.activeStage,
          entry.match,
          b,
        )) {
          throw StateError('Board oder Spieler inzwischen belegt');
        }
        await widget.onChange();
      }),
      child: Container(
        constraints: const BoxConstraints(minHeight: 48),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.play_arrow,
              color: operational && state.canStart(entry)
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).disabledColor,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                'Starten / Vorziehen',
                style: TextStyle(
                  color: operational && state.canStart(entry)
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).disabledColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
    Widget match(PlayEntry e, {int? suggestedBoard}) => _box([
      Text(_pair(e), style: Theme.of(context).textTheme.titleMedium),
      Text(e.origin),
      if (suggestedBoard != null) Text('Boardvorschlag: $suggestedBoard'),
      if (state.schedule.running.any((r) => identical(r.match, e.match)))
        Text('Läuft auf Board ${e.match.boardNumber}')
      else ...[
        if (!state.canStart(e))
          const Text('Wartet auf ein freies Board oder laufende Spieler.'),
        Align(alignment: Alignment.centerLeft, child: start(e)),
      ],
    ]);

    final status = _box([
      Text('Turnierleitung', style: Theme.of(context).textTheme.headlineSmall),
      Text('Aktive Etappe: ${t.runStages[widget.activeStage].name}'),
      const SizedBox(height: 12),
      Wrap(
        spacing: 20,
        runSpacing: 12,
        children: [
          Text(
            '$completed erledigt · ${active.length - completed} offen (bekannte Paarungen)',
          ),
          Text('${state.schedule.running.length} Spiele laufen'),
          Text('${state.freeBoards.length} Boards frei'),
          Text(
            t.startedAt == null
                ? 'Turnieruhr noch nicht gestartet'
                : 'Laufzeit: ${_duration(timing.elapsed)}',
          ),
          Text(
            timing.forecast == null
                ? 'Endzeit: noch keine belastbare Schätzung'
                : 'Geschätztes Ende: ${_clock(timing.forecast!)}',
          ),
        ],
      ),
      if (!widget.canOperate)
        const Padding(
          padding: EdgeInsets.only(top: 8),
          child: Text(
            'Spielstart derzeit gesperrt: Etappenfreigabe oder Auslosung abwarten.',
          ),
        ),
    ]);
    final notices = _box([
      Text(
        'Hinweise & Aktionen',
        style: Theme.of(context).textTheme.titleLarge,
      ),
      if (widget.saveError != null) ...[
        Text(
          widget.saveError!,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
        _button(
          'Speichern erneut versuchen',
          () => _act(widget.onChange),
          icon: Icons.save_outlined,
        ),
      ],
      if (_actionError != null) Text(_actionError!),
      for (final connection in failures)
        Text(
          'Board ${connection.key}: Übertragung oder Ergebnisübernahme von ${connection.value.device.name} fehlgeschlagen. Gerät und Speicherung prüfen.',
        ),
      if (waiting > 0)
        Text('$waiting Paarungen warten auf vorherige Ergebnisse.'),
      if (state.freeBoards.isEmpty &&
          state.schedule.running.isEmpty &&
          state.ready.isNotEmpty)
        const Text(
          'Alle Boards sind gesperrt. Ein Board freigeben, um fortzufahren.',
        ),
      if (active.isNotEmpty && completed == active.length && waiting == 0)
        const Text(
          'Etappe fertig: unten Etappe abschließen oder Turnier beenden.',
        ),
      if (widget.saveError == null &&
          _actionError == null &&
          failures.isEmpty &&
          waiting == 0 &&
          !(state.freeBoards.isEmpty && state.ready.isNotEmpty) &&
          !(active.isNotEmpty && completed == active.length))
        const Text('Keine akuten Probleme erkannt.'),
      if (t.communityId != null) ...[
        const SizedBox(height: 8),
        Text(
          'Community-Synchronisierung (appweit): ${widget.syncStatus.value}',
        ),
        _button(
          'Jetzt synchronisieren',
          () => _act(widget.onSync),
          icon: Icons.sync,
        ),
      ] else
        const Text(
          'Lokales Turnier · keine Cloud-Synchronisierung erforderlich.',
        ),
    ]);
    final boards = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _title('Boards'),
        if (t.communityId != null)
          const Text(
            'Boards sperren und freigeben benötigt das Recht „Turniere bearbeiten“.',
          ),
        _button(
          'Geräte verwalten',
          () => _act(widget.onDevices),
          icon: Icons.devices,
        ),
        for (var b = 1; b <= t.boardCount; b++)
          _box([
            Text(
              'Board $b · ${state.runningOn(b) != null
                  ? 'Belegt'
                  : t.blockedBoards.contains(b)
                  ? 'Gesperrt'
                  : 'Frei'}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(
              connections[b] == null
                  ? 'Kein Gerät zugeteilt · manuelle Ergebniseingabe möglich'
                  : '${connections[b]!.device.name} · ${connections[b]!.status.startsWith('Übertragung fehlgeschlagen') ? 'Verbindung gestört' : connections[b]!.status}',
            ),
            if (state.runningOn(b) case final e?) ...[
              const SizedBox(height: 8),
              Text(_pair(e)),
              Text(
                'Spieldauer: ${_duration(now.difference(e.match.startedAt!))}',
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _button(
                    'Ergebnis erfassen',
                    operational
                        ? () => _act(() => widget.onResult(e.match))
                        : null,
                    icon: Icons.edit_outlined,
                  ),
                ],
              ),
            ] else ...[
              if (!t.blockedBoards.contains(b))
                if (state.schedule.planned
                        .where((a) => a.board == b)
                        .firstOrNull
                    case final next?) ...[
                  Text('Nächstes Spiel: ${_pair(next.entry)}'),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: start(next.entry, board: b),
                  ),
                ],
              _button(
                t.blockedBoards.contains(b)
                    ? 'Board freigeben'
                    : 'Board sperren',
                () => _act(() => widget.onBlock(b)),
                icon: t.blockedBoards.contains(b)
                    ? Icons.lock_open
                    : Icons.block,
              ),
            ],
          ]),
      ],
    );
    final games = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _title('Nächste Spiele'),
        const Text(
          'Reihenfolge der aktiven Etappe. Vorziehen ist nur bei freien Spielern und Boards möglich.',
        ),
        if (state.ready.isEmpty)
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text('Keine weiteren spielbereiten Paarungen.'),
          ),
        PagedEntries<PlayEntry>(
          entries: state.schedule.planned.isEmpty
              ? state.ready
              : state.schedule.planned.map((a) => a.entry).toList(),
          builder: (e) => match(
            e,
            suggestedBoard: state.schedule.planned
                .where((a) => identical(a.entry.match, e.match))
                .firstOrNull
                ?.board,
          ),
        ),
      ],
    );
    final search = _box([
      TextField(
        controller: _search,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          labelText: 'Spieler suchen',
          hintText: 'Name oder Teammitglied',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _search.text.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Suche löschen',
                  icon: const Icon(Icons.clear),
                  onPressed: () => setState(_search.clear),
                ),
          border: const OutlineInputBorder(),
        ),
      ),
      if (_search.text.trim().isNotEmpty) ...[
        const SizedBox(height: 8),
        if (state.search(_search.text).isEmpty)
          const Text('Kein offenes Spiel in der aktiven Etappe gefunden.'),
        PagedEntries<PlayEntry>(
          key: ValueKey(_search.text),
          entries: state.search(_search.text),
          builder: (e) => match(e),
        ),
      ],
    ]);
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide =
            constraints.maxWidth >= 1000 &&
            MediaQuery.textScalerOf(context).scale(16) <= 24;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ExpansionTile(
              title: const Text('Turnierleiter-Einstellungen'),
              leading: const Icon(Icons.settings_outlined),
              children: [
                SwitchListTile(
                  title: const Text('Partie am Board-Gerät starten'),
                  subtitle: const Text(
                    'Zeigt auf der Vorschau der nächsten Partie einen Startknopf.',
                  ),
                  value: t.allowDeviceStart,
                  onChanged: _busy
                      ? null
                      : (value) => _act(() async {
                          final previous = t.allowDeviceStart;
                          setState(() => t.allowDeviceStart = value);
                          try {
                            await widget.onChange();
                          } catch (_) {
                            setState(() => t.allowDeviceStart = previous);
                            rethrow;
                          }
                        }),
                ),
              ],
            ),
            if (!wide)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (var i = 0; i < 3; i++)
                    ChoiceChip(
                      label: Text(['Übersicht', 'Boards', 'Spiele'][i]),
                      selected: _section == i,
                      onSelected: (_) => setState(() => _section = i),
                    ),
                ],
              ),
            if (wide || _section == 0) ...[status, notices, search],
            if (wide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: boards),
                  const SizedBox(width: 20),
                  Expanded(child: games),
                ],
              )
            else if (_section == 1) ...[
              notices,
              boards,
            ] else if (_section == 2) ...[
              search,
              games,
            ],
          ],
        );
      },
    );
  }
}
