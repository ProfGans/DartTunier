import 'dart:async';
import 'package:flutter/material.dart';
import '../../../application/tournament_director_snapshot.dart';
import '../../../application/tournament_timing.dart';
import '../../../application/order_of_play/order_of_play_controller.dart';
import '../../../domain/tournament_models.dart';
import '../../../../../shared/widgets/paged_entries.dart';
import 'tournament_second_screen_view.dart';

/// Embedded tournament controls for match scheduling and result entry.
class TournamentDirectorDashboard extends StatefulWidget {
  const TournamentDirectorDashboard({
    super.key,
    required this.tournament,
    required this.activeStage,
    required this.onChange,
    required this.onResult,
    required this.onBlock,
    this.saveError,
    this.canOperate = true,
    this.onCompleteStage,
    this.onFinishEarly,
    this.canCompleteStage = false,
    this.isLastStage = false,
  });
  final CreatedTournament tournament;
  final int activeStage;
  final Future<void> Function() onChange;
  final Future<void> Function(GroupMatch) onResult;
  final Future<void> Function(int) onBlock;
  final String? saveError;
  final bool canOperate;
  final VoidCallback? onCompleteStage;
  final VoidCallback? onFinishEarly;
  final bool canCompleteStage;
  final bool isLastStage;
  @override
  State<TournamentDirectorDashboard> createState() =>
      _TournamentDirectorDashboardState();
}

class _TournamentDirectorDashboardState
    extends State<TournamentDirectorDashboard> {
  Timer? _timer;
  final _search = TextEditingController();
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
  Widget build(BuildContext context) => _build(context);

  Widget _build(BuildContext context) {
    final t = widget.tournament;
    final state = TournamentDirectorSnapshot(t, widget.activeStage);
    final now = DateTime.now();
    final timing = TournamentTiming.snapshot(t, now);
    final active = state.entries
        .where((e) => e.stageIndex == widget.activeStage && e.match.hasPlayers)
        .toList();
    final completed = active.where((e) => e.match.isResolved).length;
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

    // Prüfe auf Ungleichgewicht der absolvierten Spiele pro Spieler in Gruppen
    final List<String> flowNotices = [];
    if (t.runStages[widget.activeStage] is GroupTournamentRunStage) {
      final groupStage = t.runStages[widget.activeStage] as GroupTournamentRunStage;
      for (final group in groupStage.groups) {
        if (group.players.length >= 3) {
          final playedMap = <TournamentPlayer, int>{};
          for (final p in group.players) {
            playedMap[p] = group.matches
                .where((m) =>
                    m.hasPlayers &&
                    m.hasResult &&
                    (m.homePlayer == p || m.awayPlayer == p))
                .length;
          }
          final sortedPlayers = group.players.toList()
            ..sort((a, b) => (playedMap[b] ?? 0).compareTo(playedMap[a] ?? 0));
          if (sortedPlayers.length >= 2) {
            final most = sortedPlayers.first;
            final least = sortedPlayers.last;
            final diff = (playedMap[most] ?? 0) - (playedMap[least] ?? 0);
            if (diff >= 2 && (playedMap[least] ?? 0) < group.matches.length) {
              flowNotices.add(
                'In ${group.name} hat ${most.name} bereits ${playedMap[most]} Partien absolviert, '
                'während ${least.name} erst ${playedMap[least]} Partien gespielt hat. '
                'Offene Partien von ${least.name} sollten priorisiert werden, um den Turnierfluss nicht zu blockieren.',
              );
            }
          }
        }
      }
    }

    final totalGames = active.length;
    final progressPct = totalGames > 0 ? ((completed / totalGames) * 100).round() : 0;

    final heroBoard = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TournamentSecondScreenView(tournament: t),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (ctx) => Dialog.fullscreen(
                child: TournamentSecondScreenView(
                  tournament: t,
                  isStandaloneWindow: true,
                ),
              ),
            ),
            child: const Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 6,
              children: [
                Icon(Icons.open_in_new, size: 18),
                Text('2. Bildschirm (TV-Vollbild) öffnen'),
              ],
            ),
          ),
        ),
      ],
    );

    final status = _box([
      Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 12,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Dashboard', style: Theme.of(context).textTheme.headlineSmall),
              Text('Aktive Etappe: ${t.runStages[widget.activeStage].name}'),
            ],
          ),
          if (widget.onCompleteStage != null || widget.onFinishEarly != null)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (widget.onFinishEarly != null)
                  OutlinedButton.icon(
                    onPressed: !widget.canCompleteStage ? widget.onFinishEarly : null,
                    icon: const Icon(Icons.block_outlined),
                    label: const Text('Vorzeitig beenden'),
                  ),
                if (widget.onCompleteStage != null)
                  FilledButton.icon(
                    onPressed: widget.canCompleteStage ? widget.onCompleteStage : null,
                    icon: Icon(
                      widget.isLastStage
                          ? Icons.check_circle_outline
                          : Icons.arrow_forward,
                    ),
                    label: Text(
                      widget.isLastStage ? 'Turnier abschließen' : 'Etappe abschließen',
                    ),
                  ),
              ],
            ),
        ],
      ),
      const SizedBox(height: 12),
      ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          value: totalGames > 0 ? (completed / totalGames).clamp(0.0, 1.0) : 0.0,
          minHeight: 8,
        ),
      ),
      const SizedBox(height: 8),
      Wrap(
        spacing: 20,
        runSpacing: 12,
        children: [
          Text(
            '$completed von $totalGames Spielen fertig ($progressPct%)',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Text('${active.length - completed} offen'),
          Text('${state.schedule.running.length} laufen gerade'),
          Text('${state.freeBoards.length} Boards frei'),
          Text(
            t.startedAt == null
                ? 'Turnieruhr nicht gestartet'
                : 'Laufzeit: ${_duration(timing.elapsed)}',
          ),
          if (timing.forecast != null)
            Text('Prognose Ende: ${_clock(timing.forecast!)}'),
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
        'Hinweise & Empfehlungen',
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
      for (final notice in flowNotices)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.priority_high, color: Colors.amber.shade800, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  notice,
                  style: TextStyle(color: Colors.amber.shade900, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
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
          'Etappe fertig: Buttons oben zum Abschließen oder vorzeitigen Beenden nutzen.',
        ),
      if (widget.saveError == null &&
          _actionError == null &&
          waiting == 0 &&
          flowNotices.isEmpty &&
          !(state.freeBoards.isEmpty && state.ready.isNotEmpty) &&
          !(active.isNotEmpty && completed == active.length))
        const Text('Keine akuten Probleme erkannt. Der Turnierbetrieb läuft flüssig.'),
    ]);
    final boards = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _title('Boards'),
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
            const Text('Manuelle Ergebniseingabe'),
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
            if (widget.saveError != null) ...[
              Card(
                color: Theme.of(context).colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: Theme.of(context).colorScheme.onErrorContainer),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.saveError!,
                          style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer, fontWeight: FontWeight.bold),
                        ),
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.refresh),
                        label: const Text('Speichern erneut versuchen'),
                        onPressed: () => _act(widget.onChange),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            heroBoard,
            const SizedBox(height: 12),
            status,
            const SizedBox(height: 12),
            notices,
            const SizedBox(height: 12),
            search,
            const SizedBox(height: 16),
            if (wide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: boards),
                  const SizedBox(width: 20),
                  Expanded(child: games),
                ],
              )
            else ...[
              boards,
              const SizedBox(height: 16),
              games,
            ],
          ],
        );
      },
    );
  }
}
