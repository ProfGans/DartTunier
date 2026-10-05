import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';
import '../../data/autoscore_setup_store.dart';

class AutoscoreVerificationPanel extends StatelessWidget {
  const AutoscoreVerificationPanel({super.key, required this.store});
  final AutoscoreSetupStore store;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: store,
    builder: (context, _) {
      final setup = store.active,
          summary = store.validationSummary(store.active.id);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Unabhängig geprüft: ${setup.independentAccuracy?.toStringAsFixed(2) ?? '—'} %',
          ),
          Text(
            '${setup.verifiedCorrect} richtig · ${setup.verifiedIncorrect} falsch · ${setup.verifiedMissing} fehlend · ${setup.verifiedExtra} Zusatzmeldungen',
          ),
          const Text(
            'Nur ausdrücklich bestätigte oder korrigierte Würfe zählen hier. Für die Prüfserie jeden Wurf prüfen und fehlende oder zusätzliche Meldungen nachtragen.',
          ),
          Text(
            'Aktuelle Prüfserie: ${summary.reviewed}/${summary.attempts} geprüft · ${summary.accuracyPercent?.toStringAsFixed(2) ?? '—'} %',
          ),
          if (summary.reviewed > 0)
            Text(
              '95-%-Untergrenze: ${summary.lowerBoundPercent.toStringAsFixed(3)} %',
            ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(48, 48),
                ),
                icon: const Icon(Icons.science_outlined),
                label: const Text('Neue Prüfserie starten'),
                onPressed: !store.loaded
                    ? null
                    : () => store.startValidationSeries(setup.id),
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(48, 48),
                ),
                icon: const Icon(Icons.download),
                label: const Text('Prüfdaten speichern'),
                onPressed: !store.loaded
                    ? null
                    : () async {
                        final json = store.exportVerification(setup.id);
                        try {
                          final location = await getSaveLocation(
                            suggestedName: 'autoscore_pruefserie.json',
                          );
                          if (location == null) return;
                          await File(location.path).writeAsString(json);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Prüfdaten gespeichert.'),
                              ),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Prüfdaten konnten nicht gespeichert werden: $e',
                                ),
                              ),
                            );
                          }
                        }
                      },
              ),
            ],
          ),
        ],
      );
    },
  );
}
