import 'package:flutter/material.dart';
import '../../../../shared/widgets/adaptive_content.dart';

class ScorerSetupWizard extends StatelessWidget {
  const ScorerSetupWizard({
    super.key,
    required this.step,
    required this.children,
    required this.onNext,
    required this.onBack,
    required this.onStart,
    required this.busy,
  });
  final int step;
  final List<Widget> children;
  final VoidCallback? onNext, onBack, onStart;
  final bool busy;
  static const titles = ['Teilnehmer', 'Spielregeln', 'Prüfen & starten'];
  static const descriptions = [
    'Wer spielt mit? Lege Spieler, Bots oder Doppelteams fest.',
    'Lege Punkte, Gewinnziel und Anwurf fest.',
    'Prüfe deine Partie. Über Zurück kannst du alles noch anpassen.',
  ];
  @override
  Widget build(BuildContext context) => AdaptiveContentList(
    key: ValueKey(step),
    maxWidth: 960,
    children: [
      Text(
        'Schritt ${step + 1} von 3',
        style: Theme.of(context).textTheme.labelLarge,
      ),
      const SizedBox(height: 8),
      LinearProgressIndicator(value: (step + 1) / 3, minHeight: 4),
      const SizedBox(height: 16),
      Text(titles[step], style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 8),
      Text(descriptions[step]),
      const SizedBox(height: 20),
      ...children,
      const SizedBox(height: 24),
      LayoutBuilder(
        builder: (context, constraints) => Wrap(
          alignment: WrapAlignment.end,
          spacing: 12,
          runSpacing: 12,
          children: [
            if (step > 0)
              OutlinedButton.icon(
                onPressed: busy ? null : onBack,
                icon: const Icon(Icons.arrow_back),
                label: const Text('Zurück'),
              ),
            FilledButton.icon(
              onPressed: busy
                  ? null
                  : step == 2
                  ? onStart
                  : onNext,
              icon: Icon(step == 2 ? Icons.play_arrow : Icons.arrow_forward),
              label: Text(
                busy
                    ? 'Spiel wird geöffnet …'
                    : step == 2
                    ? 'Spiel starten'
                    : 'Weiter',
              ),
            ),
          ],
        ),
      ),
    ],
  );
}
