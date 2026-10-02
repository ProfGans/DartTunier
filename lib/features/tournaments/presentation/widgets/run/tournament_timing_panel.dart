import 'dart:async';
import 'package:flutter/material.dart';
import '../../../domain/tournament_models.dart';
import '../../../application/tournament_timing.dart';

class TournamentTimingPanel extends StatefulWidget {
  const TournamentTimingPanel({
    super.key,
    required this.tournament,
    required this.onStart,
  });
  final CreatedTournament tournament;
  final Future<void> Function() onStart;
  @override
  State<TournamentTimingPanel> createState() => _TournamentTimingPanelState();
}

class _TournamentTimingPanelState extends State<TournamentTimingPanel> {
  Timer? _timer;
  bool _busy = false;
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
    super.dispose();
  }

  String duration(int seconds) =>
      '${seconds ~/ 3600} h ${(seconds ~/ 60) % 60} min';
  String time(DateTime date) {
    final d = date.toLocal();
    return '${d.day}.${d.month}. ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  String matchDuration(num seconds) =>
      '${seconds ~/ 60} min ${seconds.round() % 60} s';

  @override
  Widget build(BuildContext context) {
    final t = widget.tournament;
    final stats = TournamentTiming.snapshot(t, DateTime.now());
    final deadline = t.startedAt == null || t.plannedMinutes == null
        ? null
        : t.startedAt!.add(Duration(minutes: t.plannedMinutes!));
    final deviation = deadline == null || stats.forecast == null
        ? null
        : stats.forecast!.difference(deadline).inMinutes;
    final status = stats.completed == 0 && t.finishedAt == null
        ? 'Prognose nach erstem Ergebnis'
        : deviation == null
        ? 'Zeitplan noch nicht verfügbar'
        : deviation.abs() <= 1
        ? 'Im Zeitplan'
        : deviation > 0
        ? 'ca. $deviation min hinter Zeitplan'
        : 'ca. ${-deviation} min vor Zeitplan';
    return Align(
      alignment: Alignment.centerRight,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Wrap(
          alignment: WrapAlignment.end,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 4,
          children: [
            if (t.startedAt == null)
              TextButton.icon(
                onPressed: _busy
                    ? null
                    : () async {
                        setState(() => _busy = true);
                        try {
                          await widget.onStart();
                        } catch (_) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Turnierstart konnte nicht gespeichert werden. Bitte erneut versuchen.',
                                ),
                              ),
                            );
                          }
                        } finally {
                          if (mounted) setState(() => _busy = false);
                        }
                      },
                icon: const Icon(Icons.play_circle_outline),
                label: const Text('Turnieruhr starten'),
              )
            else ...[
              Text(
                '${t.finishedAt == null ? 'Laufzeit' : 'Gesamtdauer'} ${duration(stats.elapsed.inSeconds)}',
              ),
              Text(
                status,
                style: TextStyle(
                  color:
                      deviation != null && deviation > 1 && stats.completed > 0
                      ? Theme.of(context).colorScheme.error
                      : null,
                ),
              ),
              if (stats.expectedCompleted != null)
                Text(
                  '${stats.completed} Spiele fertig · ${stats.expectedCompleted} laut Zeitplan',
                ),
              if (stats.forecast != null && t.finishedAt == null)
                Text('Voraussichtliches Ende: ${time(stats.forecast!)}'),
            ],
            TextButton.icon(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Zeitplan und Matchdauer'),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t.startedAt == null
                              ? 'Start: noch nicht erfasst'
                              : 'Start: ${time(t.startedAt!)}',
                        ),
                        if (t.finishedAt != null)
                          Text('Ende: ${time(t.finishedAt!)}'),
                        if (deadline != null)
                          Text('Geplantes Ende: ${time(deadline)}'),
                        if (stats.forecast != null && stats.completed > 0)
                          Text(
                            'Voraussichtliches Ende: ${time(stats.forecast!)}',
                          ),
                        if (stats.expectedCompleted != null)
                          Text(
                            '${stats.completed} Spiele fertig · ${stats.expectedCompleted} laut Zeitplan',
                          ),
                        Text(
                          t.plannedMatchEndSeconds.isEmpty
                              ? 'Sollvergleich bei älteren Turnieren: gleichmäßige Verteilung über die geplante Dauer.'
                              : 'Sollvergleich: ursprünglicher Spielplan mit parallelen Boards und aufeinanderfolgenden Etappen. Freilose zählen nicht als Spiele.',
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '${stats.matchSeconds.length} Matches mit gemessener Dauer',
                        ),
                        if (stats.averageSeconds != null) ...[
                          Text(
                            'Durchschnitt: ${matchDuration(stats.averageSeconds!)}',
                          ),
                          Text(
                            'Kürzestes Match: ${matchDuration(stats.matchSeconds.first)}',
                          ),
                          Text(
                            'Längstes Match: ${matchDuration(stats.matchSeconds.last)}',
                          ),
                        ],
                        Text(
                          '${stats.unmeasured} Ergebnisse ohne vollständige Zeitmessung',
                        ),
                        if (stats.matchSeconds.isNotEmpty)
                          ExpansionTile(
                            title: const Text('Gemessene Matches'),
                            children: [
                              for (final match
                                  in TournamentTiming.matches(t).where(
                                    (m) =>
                                        m.hasPlayers &&
                                        !m.isAnnulled &&
                                        m.hasResult &&
                                        m.startedAt != null &&
                                        m.finishedAt != null &&
                                        !m.finishedAt!.isBefore(m.startedAt!),
                                  ))
                                ListTile(
                                  title: Text(
                                    '${match.homePlayer!.name} – ${match.awayPlayer!.name}',
                                  ),
                                  subtitle: Text(
                                    matchDuration(
                                      match.finishedAt!
                                          .difference(match.startedAt!)
                                          .inSeconds,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        const SizedBox(height: 12),
                        const Text(
                          'Die Uhr startet automatisch beim ersten gestarteten Match oder über „Turnieruhr starten“. Matchdauern reichen vom Start bis zur Ergebniserfassung. Pausen sind enthalten. Die Endzeit-Prognose folgt dem bisherigen Matchfortschritt; unterschiedliche Etappen, Boards und Spielverläufe können sie verändern.',
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Schließen'),
                    ),
                  ],
                ),
              ),
              icon: const Icon(Icons.timer_outlined),
              label: const Text('Zeitstatistik'),
            ),
          ],
        ),
      ),
    );
  }
}
