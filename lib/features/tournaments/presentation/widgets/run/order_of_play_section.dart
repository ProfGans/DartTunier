import 'package:flutter/material.dart';
import '../../../application/order_of_play/order_of_play_controller.dart';
import '../../../domain/tournament_models.dart';

class OrderOfPlaySection extends StatelessWidget {
  const OrderOfPlaySection({
    super.key,
    required this.tournament,
    required this.activeStage,
    required this.onChange,
    required this.onResult,
  });
  final CreatedTournament tournament;
  final int activeStage;
  final Future<void> Function() onChange;
  final Future<void> Function(GroupMatch) onResult;

  @override
  Widget build(BuildContext context) {
    const controller = OrderOfPlayController();
    final schedule = controller.plan(tournament, activeStage);
    final occupied = {for (final e in schedule.running) e.match.boardNumber};
    Widget title(String text) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Text(text, style: Theme.of(context).textTheme.titleLarge),
    );
    String players(PlayEntry entry) => entry.stageIndex > activeStage
        ? 'Qualifikation noch offen – Qualifikation noch offen'
        : '${entry.match.homePlayer?.name ?? 'Noch offen'} – ${entry.match.awayPlayer?.name ?? 'Noch offen'}';
    Widget row(PlayEntry entry, String detail, {Widget? action}) => Card(
      child: ListTile(
        title: Text(players(entry)),
        subtitle: Text('${entry.origin}\n$detail'),
        isThreeLine: true,
        trailing: action,
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Order of Play', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 12),
        DropdownButtonFormField<int>(
          key: ValueKey(tournament.boardCount),
          initialValue: tournament.boardCount,
          decoration: const InputDecoration(
            labelText: 'Verfügbare Boards',
            border: OutlineInputBorder(),
          ),
          items: [
            for (var count = 1; count <= 64; count++)
              DropdownMenuItem(
                value: count,
                enabled: !occupied.any(
                  (board) => board != null && board > count,
                ),
                child: Text('$count Boards'),
              ),
          ],
          onChanged: (value) async {
            if (value == null) return;
            tournament.boardCount = value;
            await onChange();
          },
        ),
        const SizedBox(height: 12),
        const Text(
          'Gleiche Blöcke laufen parallel. Die Planung bevorzugt lange Pausen und belegte Boards; gleichmäßige Pausen sind nicht immer möglich. Starten reserviert Board und Spieler. Vorziehen ist auf jedem freien Board möglich und plant die restlichen Matches neu. Zeitblöcke sind eine Reihenfolge, keine festen Uhrzeiten.',
        ),
        if (schedule.finished.isNotEmpty) ...[
          title('Abgeschlossen · nach Ergebniseingang'),
          for (final entry in schedule.finished)
            row(
              entry,
              entry.match.isAnnulled
                  ? 'Annulliert'
                  : !entry.match.hasPlayers
                  ? 'Freilos · kein Board nötig'
                  : '${entry.match.scoreLabel} · ${entry.match.boardNumber == null ? 'Board nicht erfasst' : 'Board ${entry.match.boardNumber}'} · ${entry.match.finishedAt?.toLocal().toString().substring(0, 16) ?? 'Reihenfolge früherer Spiele nicht erfasst'}',
              action: entry.stageIndex == activeStage && entry.match.hasPlayers
                  ? IconButton(
                      tooltip: 'Ergebnis bearbeiten',
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () => onResult(entry.match),
                    )
                  : null,
            ),
        ],
        title('Laufende Matches'),
        if (schedule.running.isEmpty) const Text('Noch kein Match gestartet.'),
        for (final entry in schedule.running)
          row(
            entry,
            'Board ${entry.match.boardNumber} · läuft seit ${entry.match.startedAt!.toLocal().toString().substring(11, 16)}',
            action: PopupMenuButton<String>(
              tooltip: 'Match verwalten',
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'result',
                  child: Text('Ergebnis eingeben'),
                ),
                PopupMenuItem(
                  value: 'cancel',
                  child: Text('Start zurücknehmen'),
                ),
              ],
              onSelected: (value) async {
                if (value == 'result') {
                  await onResult(entry.match);
                } else {
                  entry.match.startedAt = null;
                  entry.match.boardNumber = null;
                  await onChange();
                }
              },
            ),
          ),
        title('Geplante Matches · chronologisch'),
        if (schedule.planned.isEmpty)
          const Text(
            'Keine weiteren spielbereiten Matches in der aktiven Etappe.',
          ),
        for (final assignment in schedule.planned)
          row(
            assignment.entry,
            'Block ${assignment.block + 1} · Board ${assignment.board}',
            action: PopupMenuButton<int>(
              tooltip: 'Starten / vorziehen',
              enabled:
                  !schedule.running.any(
                    (e) => e.players.any(assignment.entry.players.contains),
                  ) &&
                  occupied.length < tournament.boardCount,
              itemBuilder: (_) => [
                for (var board = 1; board <= tournament.boardCount; board++)
                  if (!occupied.contains(board))
                    PopupMenuItem(
                      value: board,
                      child: Text('Auf Board $board starten'),
                    ),
              ],
              onSelected: (board) async {
                if (controller.start(
                  tournament,
                  activeStage,
                  assignment.entry.match,
                  board,
                )) {
                  await onChange();
                }
              },
              icon: const Icon(Icons.play_arrow),
            ),
          ),
        if (schedule.waiting.isNotEmpty) ...[
          title('Wartet auf Ergebnisse / Etappenfreigabe'),
          const Text(
            'Diese Matches bekommen ihre Board-Zuordnung, sobald die Paarungen und die Etappe freigegeben sind.',
          ),
          for (final entry in schedule.waiting)
            row(entry, 'Noch nicht eingeplant'),
        ],
      ],
    );
  }
}
