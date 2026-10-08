import 'board_match_card.dart';
import 'participant_match_picker.dart';
import 'play_queue_block.dart';
import '../../../../../shared/widgets/sport_settings_section.dart';
import '../../../../../shared/widgets/sport_menu.dart';
import 'package:flutter/material.dart';
import '../../../application/order_of_play/order_of_play_controller.dart';
import '../../../domain/tournament_models.dart';
import '../../../../statistics/domain/match_scorer_summary.dart';
import '../../../../statistics/presentation/tournament_match_statistics_page.dart';

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
    Widget row(PlayEntry entry, String detail, {Widget? action}) =>
        MatchStatisticsTapTarget(match: entry.match, child: BoardMatchCard(
          home: entry.stageIndex > activeStage
              ? 'Qualifikation noch offen'
              : entry.match.homePlayer?.name ?? 'Noch offen',
          away: entry.stageIndex > activeStage
              ? 'Qualifikation noch offen'
              : entry.match.awayPlayer?.name ?? 'Noch offen',
          origin: entry.origin,
          status: detail,
          running: schedule.running.contains(entry),
          scorerSummary: MatchScorerSummary.fromMatch(
            entry.match,
          )?.averageLabel,
          action: action,
        ));
    Widget plannedRow(BoardAssignment assignment, bool next) => PlayQueueMatch(
      key: ObjectKey(assignment.entry.match),
      home: assignment.entry.match.homePlayer?.name ?? 'Noch offen',
      away: assignment.entry.match.awayPlayer?.name ?? 'Noch offen',
      origin: assignment.entry.origin,
      board: assignment.board,
      action: PopupMenuButton<int>(
        tooltip: 'Starten / vorziehen',
        enabled:
            !schedule.running.any(
              (e) => e.players.any(assignment.entry.players.contains),
            ) &&
            occupied.length < tournament.boardCount,
        itemBuilder: (_) => [
          for (var board = 1; board <= tournament.boardCount; board++)
            if (!occupied.contains(board) && !tournament.blockedBoards.contains(board))
              PopupMenuItem(
                value: board,
                child: SportMenuLabel(
                  label: 'Auf Board $board starten',
                  icon: Icons.play_arrow_outlined,
                ),
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
        child: Padding(
          padding: EdgeInsets.all(12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.play_arrow),
              SizedBox(width: 8),
              Flexible(child: Text(next ? 'Starten' : 'Vorziehen')),
            ],
          ),
        ),
      ),
    );
    final firstBlock = schedule.planned.firstOrNull?.block;
    final blocks = <int, List<BoardAssignment>>{};
    for (final assignment in schedule.planned) {
      blocks.putIfAbsent(assignment.block, () => []).add(assignment);
    }
    final orderedBlocks = blocks.keys.toList()..sort();
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Order of Play',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            Text(
              '${schedule.running.length} laufend · ${schedule.planned.length} eingeplant · ${schedule.finished.length} erledigt',
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              isExpanded: true,
              itemHeight: null,
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
                    child: Text(count == 1 ? '1 Board' : '$count Boards'),
                  ),
              ],
              onChanged: (value) async {
                if (value == null) return;
                tournament.boardCount = value;
                await onChange();
              },
            ),
            const SizedBox(height: 12),
            ParticipantMatchPicker(tournament: tournament, activeStage: activeStage, onChange: onChange),
            if (schedule.running.isNotEmpty) title('Jetzt auf den Boards'),
            for (final entry in schedule.running)
              row(
                entry,
                'Board ${entry.match.boardNumber} · läuft seit ${entry.match.startedAt!.toLocal().toString().substring(11, 16)}',
                action: PopupMenuButton<String>(
                  tooltip: 'Match verwalten',
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'result',
                      child: SportMenuLabel(
                        label: 'Ergebnis eingeben',
                        icon: Icons.arrow_forward_outlined,
                      ),
                    ),
                    PopupMenuItem(
                      value: 'cancel',
                      child: SportMenuLabel(
                        label: 'Start zurücknehmen',
                        icon: Icons.play_arrow_outlined,
                      ),
                    ),
                  ],
                  onSelected: (value) async {
                    if (value == 'result') {
                      await onResult(entry.match);
                    } else {
                      entry.match.startedAt = null;
                      entry.match.startedPlayers = null;
                      entry.match.boardNumber = null;
                      await onChange();
                    }
                  },
                ),
              ),
            title('Geplante Reihenfolge'),
            const Text(
              'Von oben nach unten spielen. Spiele im selben Block sind parallel vorgesehen.',
            ),
            const SizedBox(height: 12),
            if (orderedBlocks.isEmpty)
              const Text(
                'Keine weiteren spielbereiten Matches in der aktiven Etappe.',
              ),
            for (final block in orderedBlocks)
              PlayQueueBlock(
                key: ValueKey('play-block-$block'),
                number: block + 1,
                next: block == firstBlock,
                waitingForBoards: block > 0 && schedule.running.isNotEmpty,
                parallelCount: blocks[block]!.length,
                children: [
                  for (final assignment in blocks[block]!)
                    plannedRow(assignment, block == firstBlock),
                ],
              ),
            if (schedule.finished.isNotEmpty) ...[
              SportSettingsSection(
                title: 'Abgeschlossene Matches',
                summary: '${schedule.finished.length} Ergebnisse',
                icon: Icons.check_circle_outline,
                children: [
                  title('Abgeschlossen · nach Ergebniseingang'),
                  for (final entry in schedule.finished)
                    row(
                      entry,
                      entry.match.isAnnulled
                          ? 'Annulliert'
                          : !entry.match.hasPlayers
                          ? 'Freilos · kein Board nötig'
                          : '${entry.match.scoreLabel} · ${entry.match.boardNumber == null ? 'Board nicht erfasst' : 'Board ${entry.match.boardNumber}'} · ${entry.match.finishedAt?.toLocal().toString().substring(0, 16) ?? 'Reihenfolge früherer Spiele nicht erfasst'}',
                      action:
                          entry.stageIndex == activeStage &&
                              entry.match.hasPlayers
                          ? IconButton(
                              tooltip: 'Ergebnis bearbeiten',
                              icon: const Icon(Icons.edit_outlined),
                              onPressed: () => onResult(entry.match),
                            )
                          : null,
                    ),
                ],
              ),
            ],
            if (schedule.waiting.isNotEmpty) ...[
              SportSettingsSection(
                title: 'Weitere Paarungen',
                summary:
                    '${schedule.waiting.length} warten auf Ergebnisse oder Freigabe',
                children: [
                  title('Wartet auf Ergebnisse / Etappenfreigabe'),
                  const Text(
                    'Diese Matches bekommen ihre Board-Zuordnung, sobald die Paarungen und die Etappe freigegeben sind.',
                  ),
                  for (final entry in schedule.waiting)
                    row(entry, 'Noch nicht eingeplant'),
                ],
              ),
            ],
            const SportSettingsSection(
              title: 'Spielplan verstehen',
              summary: 'Boards, Pausen und Zeitblöcke erklärt',
              icon: Icons.info_outline,
              children: [
                Text(
                  'Gleiche Blöcke laufen parallel. Die Planung bevorzugt lange Pausen und belegte Boards; gleichmäßige Pausen sind nicht immer möglich. Starten reserviert Board und Spieler. Vorziehen ist auf jedem freien Board möglich und plant die restlichen Matches neu. Zeitblöcke sind eine Reihenfolge, keine festen Uhrzeiten.',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
