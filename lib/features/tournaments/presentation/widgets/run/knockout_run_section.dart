import 'package:flutter/material.dart';

import '../../../domain/tournament_models.dart';
import 'stage_surface.dart';

typedef KnockoutBracketBuilder =
    Widget Function(
      KnockoutTournamentRunStage stage,
      int qualifyingRank,
      void Function(GroupMatch match) onEditResult,
      bool canEditResults,
      bool isEditMode,
      void Function(int fromSlotIndex, int toSlotIndex) onSwapSlot,
    );

class KnockoutRunSection extends StatelessWidget {
  const KnockoutRunSection({
    super.key,
    required this.stage,
    required this.qualifyingRank,
    required this.onEditResult,
    required this.canEditResults,
    required this.isEditMode,
    required this.canEditBracket,
    required this.onEditModeChanged,
    required this.onSwapSlot,
    required this.bracketBuilder,
  });

  final KnockoutTournamentRunStage stage;
  final int qualifyingRank;
  final void Function(GroupMatch match) onEditResult;
  final bool canEditResults;
  final bool isEditMode;
  final bool canEditBracket;
  final ValueChanged<bool> onEditModeChanged;
  final void Function(int fromSlotIndex, int toSlotIndex) onSwapSlot;
  final KnockoutBracketBuilder bracketBuilder;

  @override
  Widget build(BuildContext context) {
    return StageSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            stage.name,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            stage.eliminationLossLimit == 1
                ? 'Turnierbaum'
                : 'Eliminationsplan - Aus nach ${stage.eliminationLossLimit} Niederlagen',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: canEditBracket
                  ? () => onEditModeChanged(!isEditMode)
                  : null,
              icon: Icon(
                isEditMode ? Icons.check_circle_outline : Icons.open_with,
              ),
              label: Text(
                isEditMode
                    ? 'Bearbeitung beenden'
                    : 'Positionen bearbeiten',
              ),
            ),
          ),
          if (!canEditBracket) ...[
            const SizedBox(height: 8),
            Text(
              canEditResults
                  ? 'Positionen koennen nur geaendert werden, solange in dieser K.-o.-Etappe noch kein Ergebnis eingetragen ist.'
                  : 'Positionen koennen nur in der aktuellen Etappe bearbeitet werden.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ] else if (isEditMode) ...[
            const SizedBox(height: 8),
            Text(
              'Ziehe Spieler in Runde 1 auf einen anderen Platz oder ein Freilos.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: 12),
          if (stage.rounds.isEmpty)
            const Text('Keine Paarungen in dieser Etappe.')
          else
            bracketBuilder(
              stage,
              qualifyingRank,
              onEditResult,
              canEditResults,
              isEditMode && canEditBracket,
              onSwapSlot,
            ),
        ],
      ),
    );
  }
}
