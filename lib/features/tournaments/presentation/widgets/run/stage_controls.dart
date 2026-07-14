import 'package:flutter/material.dart';

import '../../../domain/tournament_models.dart';

enum StageViewMode { overview, playOrder }

class StageProgressBar extends StatelessWidget {
  const StageProgressBar({
    super.key,
    required this.stages,
    required this.activeStageIndex,
    required this.completedStageIndexes,
    required this.onStageSelected,
  });

  final List<TournamentRunStage> stages;
  final int activeStageIndex;
  final Set<int> completedStageIndexes;
  final ValueChanged<int> onStageSelected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: colorScheme.surfaceContainerHighest,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            for (var index = 0; index < stages.length; index++) ...[
              _StageProgressChip(
                label: stages[index].name,
                number: index + 1,
                isActive: index == activeStageIndex,
                isComplete: completedStageIndexes.contains(index),
                onTap: () => onStageSelected(index),
              ),
              if (index < stages.length - 1)
                Container(
                  width: 28,
                  height: 1,
                  color: colorScheme.outlineVariant,
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StageProgressChip extends StatelessWidget {
  const _StageProgressChip({
    required this.label,
    required this.number,
    required this.isActive,
    required this.isComplete,
    required this.onTap,
  });

  final String label;
  final int number;
  final bool isActive;
  final bool isComplete;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final backgroundColor = isActive
        ? colorScheme.primaryContainer
        : colorScheme.surface;
    final borderColor = isActive
        ? colorScheme.primary
        : colorScheme.outlineVariant;

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: backgroundColor,
          border: Border.all(color: borderColor),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 13,
              backgroundColor: isComplete
                  ? colorScheme.primary
                  : colorScheme.surface,
              child: Icon(
                isComplete ? Icons.check : Icons.flag_outlined,
                size: 15,
                color: isComplete ? colorScheme.onPrimary : colorScheme.primary,
              ),
            ),
            const SizedBox(width: 8),
            Text('$number. $label'),
          ],
        ),
      ),
    );
  }
}

class StageViewModeSwitch extends StatelessWidget {
  const StageViewModeSwitch({
    super.key,
    required this.selectedMode,
    required this.onModeChanged,
  });

  final StageViewMode selectedMode;
  final ValueChanged<StageViewMode> onModeChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: SegmentedButton<StageViewMode>(
        segments: const [
          ButtonSegment(
            value: StageViewMode.overview,
            icon: Icon(Icons.view_agenda_outlined),
            label: Text('Uebersicht'),
          ),
          ButtonSegment(
            value: StageViewMode.playOrder,
            icon: Icon(Icons.format_list_numbered),
            label: Text('Spielansicht'),
          ),
        ],
        selected: {selectedMode},
        onSelectionChanged: (selection) => onModeChanged(selection.first),
      ),
    );
  }
}

class StageFooter extends StatelessWidget {
  const StageFooter({
    super.key,
    required this.canCompleteStage,
    required this.isLastStage,
    required this.isViewingActiveStage,
    required this.activeStageName,
    required this.onCompleteStage,
    required this.onFinishEarly,
  });

  final bool canCompleteStage;
  final bool isLastStage;
  final bool isViewingActiveStage;
  final String activeStageName;
  final VoidCallback onCompleteStage;
  final VoidCallback onFinishEarly;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border: Border(
            top: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              !isViewingActiveStage
                  ? 'Vorschau: Ergebnisse und Abschluss sind nur in der aktuellen Etappe "$activeStageName" moeglich.'
                  : canCompleteStage
                  ? 'Alle Ergebnisse dieser Etappe sind eingetragen.'
                  : 'Trage alle Ergebnisse ein, um die Etappe abzuschliessen.',
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: isViewingActiveStage && !canCompleteStage
                      ? onFinishEarly
                      : null,
                  icon: const Icon(Icons.block_outlined),
                  label: const Text('Etappe vorzeitig beenden'),
                ),
                FilledButton.icon(
                  onPressed: canCompleteStage && isViewingActiveStage
                      ? onCompleteStage
                      : null,
                  icon: Icon(
                    isLastStage
                        ? Icons.check_circle_outline
                        : Icons.arrow_forward,
                  ),
                  label: Text(
                    isLastStage
                        ? 'Turnier abschliessen'
                        : 'Etappe abschliessen',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
