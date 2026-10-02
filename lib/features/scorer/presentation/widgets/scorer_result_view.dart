import 'package:flutter/material.dart';
import '../../../../shared/widgets/adaptive_content.dart';
import '../../domain/scorer_settings.dart';
import '../../domain/scorer_statistics.dart';
import '../../domain/x01/x01_models.dart';
import '../checkout_page.dart' show checkoutLabel;

class ScorerResultView extends StatelessWidget {
  const ScorerResultView({
    super.key,
    required this.settings,
    required this.statistics,
    required this.sets,
    required this.winner,
    required this.onStatistics,
    required this.onClose,
    required this.onUndo,
  });
  final ScorerSettings settings;
  final ScorerStatistics statistics;
  final List<int> sets;
  final int? winner;
  final VoidCallback onStatistics;
  final VoidCallback? onClose, onUndo;

  String number(double? n) => n?.toStringAsFixed(2).replaceAll('.', ',') ?? '—';

  @override
  Widget build(BuildContext context) => AdaptiveContentList(
    children: [
      Icon(
        winner == null ? Icons.handshake_outlined : Icons.emoji_events_outlined,
        size: 56,
        color: Theme.of(context).colorScheme.primary,
      ),
      const SizedBox(height: 12),
      Text(
        winner == null
            ? 'Unentschieden!'
            : '${settings.participants[winner!].name} gewinnt!',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.headlineMedium,
      ),
      const SizedBox(height: 8),
      Text(
        'Spiel beendet · ${settings.startScore} · ${checkoutLabel(settings.checkoutRequirement)}',
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 20),
      AdaptiveTileLayout(
        children: [
          for (var i = 0; i < settings.participants.length; i++)
            Card(
              color: i == winner
                  ? Theme.of(context).colorScheme.primaryContainer
                  : null,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      settings.participants[i].name,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text(
                      '${statistics.players[i].legsWon} Legs gewonnen'
                      '${settings.bestOfSets > 1 ? ' · ${sets[i]} Sets' : ''}',
                    ),
                    const Divider(),
                    _metric(
                      '3-Dart-Average',
                      number(statistics.players[i].average),
                    ),
                    _metric(
                      'First-9-Average',
                      number(statistics.players[i].firstNineAverage),
                    ),
                    if (settings.checkoutRequirement ==
                        CheckoutRequirement.doubleOut)
                      _metric(
                        'Checkoutquote',
                        statistics.players[i].unknownCheckoutVisits > 0
                            ? 'Unvollständig'
                            : statistics.players[i].checkoutPercent == null
                            ? '—'
                            : '${number(statistics.players[i].checkoutPercent)} %',
                      ),
                    _metric(
                      'Höchstes Finish',
                      statistics.players[i].legsWon == 0
                          ? '—'
                          : '${statistics.players[i].highestFinish}',
                    ),
                    _metric(
                      'Bestes Leg',
                      statistics.players[i].bestLeg == null
                          ? '—'
                          : '${statistics.players[i].bestLeg} Darts',
                    ),
                    _metric(
                      'Höchste Aufnahme',
                      '${statistics.players[i].highestScore}',
                    ),
                    _metric('180er', '${statistics.players[i].scores180}'),
                  ],
                ),
              ),
            ),
        ],
      ),
      const SizedBox(height: 16),
      Wrap(
        spacing: 12,
        runSpacing: 12,
        alignment: WrapAlignment.center,
        children: [
          FilledButton.icon(
            onPressed: onClose,
            icon: const Icon(Icons.check),
            label: const Text('Spiel abschließen'),
          ),
          OutlinedButton.icon(
            onPressed: onStatistics,
            icon: const Icon(Icons.bar_chart),
            label: const Text('Alle Statistiken'),
          ),
          Tooltip(
            message: 'Rückgängig',
            child: TextButton.icon(
              onPressed: onUndo,
              icon: const Icon(Icons.undo),
              label: const Text('Letzte Eingabe korrigieren'),
            ),
          ),
        ],
      ),
    ],
  );

  Widget _metric(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Wrap(
      alignment: WrapAlignment.spaceBetween,
      spacing: 12,
      runSpacing: 4,
      children: [
        Text(label),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    ),
  );
}
