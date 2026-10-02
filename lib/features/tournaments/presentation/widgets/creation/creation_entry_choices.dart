import 'package:flutter/material.dart';
import '../../../../../shared/widgets/adaptive_content.dart';

class CreationEntryChoices extends StatelessWidget {
  const CreationEntryChoices({super.key, required this.onFind, required this.onExpert, required this.onLeague});
  final VoidCallback onFind;
  final VoidCallback onExpert;
  final VoidCallback onLeague;

  @override
  Widget build(BuildContext context) => AdaptiveContentList(children: [
    Text('Wie möchtest du dein Turnier erstellen?',
        style: Theme.of(context).textTheme.headlineSmall),
    const SizedBox(height: 24),
    AdaptiveTileLayout(children: [
      _choice(context, 'Turnierform finden',
          'Lass dir einen passenden Aufbau vorschlagen. Anschließend kannst du '
          'Spieler, Etappen und Spielformate noch anpassen.', Icons.search, onFind),
      _choice(context, 'Expertenmodus',
          'Erstelle dein Turnier wie gewohnt und lege Spieler, Etappen und '
          'Regeln selbst fest.', Icons.tune, onExpert),
      _choice(context, 'Ligaspiel',
          'Ligaspiel mit Heim- und Gastmannschaft: 16 Einzel und 2 Doppel, '
          '501 Double Out, Best of 5. Aufstellungen und Reihenfolge sind anpassbar.',
          Icons.groups, onLeague),
    ]),
  ]);

  Widget _choice(BuildContext context, String title, String description,
      IconData icon, VoidCallback action) => Card(
    child: Padding(padding: const EdgeInsets.all(20), child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 32),
        const SizedBox(height: 12),
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        Text(description),
        const SizedBox(height: 20),
        FilledButton(onPressed: action,
          style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
          child: Text(title)),
      ],
    )),
  );
}
