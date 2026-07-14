import 'package:flutter/material.dart';

import '../../../domain/tournament_models.dart';

class MiniKnockoutGroupRunSection extends StatelessWidget {
  const MiniKnockoutGroupRunSection({
    super.key,
    required this.group,
    required this.bracket,
  });

  final TournamentGroup group;
  final Widget bracket;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            group.name,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            group.playType == 'mini_knockout'
                ? 'Mini-KO-Runde'
                : _groupPlayTypeLabel(group.playType),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          if (group.knockoutRounds.isEmpty)
            const Text('Keine Paarungen in dieser Gruppe.')
          else
            bracket,
        ],
      ),
    );
  }
}

String _groupPlayTypeLabel(String playType) {
  return switch (playType) {
    'round_robin' => 'Jeder gegen jeden',
    'mini_knockout' => 'Mini-KO in der Gruppe',
    'double_elimination' => 'Doppel-KO in der Gruppe',
    'triple_elimination' => 'Triple-KO in der Gruppe',
    _ => playType,
  };
}
