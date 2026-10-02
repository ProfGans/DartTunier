import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../domain/scorer_settings.dart';
import '../../domain/scorer_statistics.dart';

/// Traditional score/rest sheet, limited to the currently displayed leg.
class ScorerLegSheet extends StatefulWidget {
  const ScorerLegSheet({
    super.key,
    required this.settings,
    required this.visits,
    required this.leg,
    required this.starter,
  });
  final ScorerSettings settings;
  final List<ScorerVisit> visits;
  final int leg, starter;

  @override
  State<ScorerLegSheet> createState() => _ScorerLegSheetState();
}

class _ScorerLegSheetState extends State<ScorerLegSheet> {
  final _scroll = ScrollController();
  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final visits = widget.visits.where((v) => v.leg == widget.leg).toList();
    final starter = visits.isEmpty ? widget.starter : visits.first.starter;
    final count = widget.settings.participants.length;
    final order = [for (var i = 0; i < count; i++) (starter + i) % count];
    final grouped = [
      for (var p = 0; p < count; p++)
        visits.where((v) => v.player == p).toList(),
    ];
    final rounds = grouped.fold<int>(0, (n, v) => math.max(n, v.length));
    Widget cell(String text, {bool bold = false}) => Padding(
      padding: const EdgeInsets.all(10),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: bold ? const TextStyle(fontWeight: FontWeight.bold) : null,
      ),
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Schreibertafel · Leg ${widget.leg + 1}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'Je Aufnahme: geworfene Punkte → Rest. Überworfen zählt 0 Punkte.',
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final width = math.max(
                  constraints.maxWidth,
                  72.0 + count * 180,
                );
                final overflow = width > constraints.maxWidth;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (overflow)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 8),
                        child: Text('↔ Seitlich scrollen für weitere Spieler'),
                      ),
                    Scrollbar(
                      controller: _scroll,
                      thumbVisibility: overflow,
                      child: SingleChildScrollView(
                        controller: _scroll,
                        scrollDirection: Axis.horizontal,
                        padding: EdgeInsets.only(bottom: overflow ? 16 : 0),
                        child: SizedBox(
                          width: width,
                          child: Table(
                            columnWidths: const {0: FixedColumnWidth(72)},
                            defaultVerticalAlignment:
                                TableCellVerticalAlignment.middle,
                            border: TableBorder.all(
                              color: Theme.of(
                                context,
                              ).colorScheme.outlineVariant,
                            ),
                            children: [
                              TableRow(
                                decoration: BoxDecoration(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.surfaceContainerHighest,
                                ),
                                children: [
                                  cell('Nr.', bold: true),
                                  for (final p in order)
                                    cell(
                                      '${widget.settings.participants[p].name}${p == starter ? ' · Anwurf' : ''}',
                                      bold: true,
                                    ),
                                ],
                              ),
                              TableRow(
                                children: [
                                  cell('Start'),
                                  for (final p in order)
                                    cell(
                                      '${widget.settings.participants[p].startScore ?? widget.settings.startScore}',
                                      bold: true,
                                    ),
                                ],
                              ),
                              for (var round = 0; round < rounds; round++)
                                TableRow(
                                  children: [
                                    cell('${round + 1}'),
                                    for (final p in order)
                                      if (round >= grouped[p].length)
                                        cell('—')
                                      else
                                        cell(
                                          _visitLabel(grouped[p][round]),
                                          bold: grouped[p][round].finished,
                                        ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
            if (rounds == 0)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Text(
                  'Noch keine abgeschlossene Aufnahme in diesem Leg.',
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _visitLabel(ScorerVisit v) => v.bust
      ? '0 → ${v.remaining}\nÜberworfen'
      : '${v.points} → ${v.remaining}${v.finished ? '\nCheckout · ${v.darts} Dart${v.darts == 1 ? '' : 's'}' : ''}';
}
