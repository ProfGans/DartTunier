part of 'main.dart';

class _StageProgressBar extends StatelessWidget {
  const _StageProgressBar({
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

enum StageViewMode { overview, playOrder }

class _StageViewModeSwitch extends StatelessWidget {
  const _StageViewModeSwitch({
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
            label: Text('Übersicht'),
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

class _StagePlayOrderSection extends StatelessWidget {
  const _StagePlayOrderSection({
    required this.stage,
    required this.matches,
    required this.onEditResult,
    required this.canEditResults,
  });

  final TournamentRunStage stage;
  final List<GroupMatch> matches;
  final void Function(GroupMatch match) onEditResult;
  final bool canEditResults;

  @override
  Widget build(BuildContext context) {
    final rounds = <int, List<GroupMatch>>{};
    for (final match in matches) {
      rounds.putIfAbsent(match.round, () => []).add(match);
    }
    final groupLabels = _groupLabelsByMatch();

    return _StageSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            stage.name,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            'Spielreihenfolge',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          if (matches.isEmpty)
            const Text('Keine Spiele in dieser Etappe.')
          else
            for (final round in rounds.keys.toList()..sort()) ...[
              _RoundHeader(round: round),
              for (final match in rounds[round]!)
                _MatchResultTile(
                  match: match,
                  onEditResult: onEditResult,
                  canEditResult: canEditResults,
                  originLabel: groupLabels[match],
                  leadingLabel: match.isDecider ? match.label : null,
                ),
              const SizedBox(height: 8),
            ],
        ],
      ),
    );
  }

  Map<GroupMatch, String> _groupLabelsByMatch() {
    final currentStage = stage;
    if (currentStage is! GroupTournamentRunStage) {
      return const {};
    }

    return {
      for (final group in currentStage.groups)
        for (final match in group.matches) match: group.name,
    };
  }
}

class _RoundHeader extends StatelessWidget {
  const _RoundHeader({required this.round});

  final int round;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            Icons.repeat_outlined,
            size: 18,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Text(
            'Runde $round',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

class _StageFooter extends StatelessWidget {
  const _StageFooter({
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

class MatchResult {
  const MatchResult({
    required this.homeLegs,
    required this.awayLegs,
    this.isAnnulled = false,
  });

  const MatchResult.annulled()
    : homeLegs = null,
      awayLegs = null,
      isAnnulled = true;

  final int? homeLegs;
  final int? awayLegs;
  final bool isAnnulled;
}

class _GroupStageRunSection extends StatelessWidget {
  const _GroupStageRunSection({
    required this.stage,
    required this.standingsFor,
    required this.onEditResult,
    required this.canEditResults,
  });

  final GroupTournamentRunStage stage;
  final List<PlayerStanding> Function(
    TournamentGroup group,
    List<String> tieBreakers,
  )
  standingsFor;
  final void Function(GroupMatch match) onEditResult;
  final bool canEditResults;

  @override
  Widget build(BuildContext context) {
    final standingsByGroup = {
      for (final group in stage.groups)
        if (group.playType == 'round_robin')
          group: standingsFor(group, stage.tieBreakers),
    };

    return _StageSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            stage.name,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          for (var index = 0; index < stage.groups.length; index++)
            if (_isEliminationGroupPlayType(stage.groups[index].playType))
              _MiniKnockoutGroupRunSection(
                group: stage.groups[index],
                qualifyingRank: _requiredRankForMiniGroup(stage, index),
                onEditResult: onEditResult,
                canEditResults: canEditResults,
              )
            else
              _GroupRunSection(
                group: stage.groups[index],
                groupNumber: index + 1,
                qualificationPlan: stage.qualificationPlan,
                tieBreakers: stage.tieBreakers,
                standings: standingsByGroup[stage.groups[index]]!,
                onEditResult: onEditResult,
                canEditResults: canEditResults,
              ),
          if (stage.qualificationPlan != null &&
              stage.qualificationPlan!.extraCount > 0 &&
              stage.groups.every((group) => group.playType == 'round_robin')) ...[
            const SizedBox(height: 4),
            _BestOfComparisonTable(
              stage: stage,
              standingsByGroup: standingsByGroup,
            ),
          ],
        ],
      ),
    );
  }

  int _requiredRankForMiniGroup(GroupTournamentRunStage stage, int groupIndex) {
    final plan = stage.qualificationPlan;
    if (plan == null) {
      return 1;
    }

    final fixedForGroup = groupIndex < plan.fixedByGroup.length
        ? plan.fixedByGroup[groupIndex]
        : plan.fixedPerGroup;
    final groupNumber = groupIndex + 1;
    final extraRank = plan.extraGroups.contains(groupNumber)
        ? plan.extraRank
        : 0;
    final requiredRank = fixedForGroup > extraRank ? fixedForGroup : extraRank;
    return requiredRank < 1 ? 1 : requiredRank;
  }
}

class _MiniKnockoutGroupRunSection extends StatelessWidget {
  const _MiniKnockoutGroupRunSection({
    required this.group,
    required this.qualifyingRank,
    required this.onEditResult,
    required this.canEditResults,
  });

  final TournamentGroup group;
  final int qualifyingRank;
  final void Function(GroupMatch match) onEditResult;
  final bool canEditResults;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final bracketStage = KnockoutTournamentRunStage(
      name: group.name,
      rounds: group.knockoutRounds,
      eliminationLossLimit: group.eliminationLossLimit,
    );

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
            _KnockoutBracketView(
              stage: bracketStage,
              qualifyingRank: qualifyingRank,
              onEditResult: onEditResult,
              canEditResults: canEditResults,
            ),
          if (group.placementMatches.isNotEmpty) ...[
            const SizedBox(height: 14),
            _PlacementMatchesSection(
              matches: group.placementMatches,
              qualifyingRank: qualifyingRank,
              onEditResult: onEditResult,
              canEditResults: canEditResults,
            ),
          ],
        ],
      ),
    );
  }
}

class _BestOfComparisonTable extends StatelessWidget {
  const _BestOfComparisonTable({
    required this.stage,
    required this.standingsByGroup,
  });

  final GroupTournamentRunStage stage;
  final Map<TournamentGroup, List<PlayerStanding>> standingsByGroup;

  int _compareCandidates(BestOfCandidate a, BestOfCandidate b) {
    for (final tieBreaker in stage.tieBreakers) {
      final comparison = switch (tieBreaker) {
        'points' => b.standing.points.compareTo(a.standing.points),
        'legDifference' => b.standing.legDifference.compareTo(
          a.standing.legDifference,
        ),
        'legsFor' => b.standing.legsFor.compareTo(a.standing.legsFor),
        _ => 0,
      };

      if (comparison != 0) {
        return comparison;
      }
    }

    final groupCompare = a.groupNumber.compareTo(b.groupNumber);
    if (groupCompare != 0) {
      return groupCompare;
    }
    return a.standing.player.name.compareTo(b.standing.player.name);
  }

  bool _allCandidateGroupsComplete(List<BestOfCandidate> candidates) {
    return candidates.every((candidate) {
      final group = stage.groups[candidate.groupNumber - 1];
      return group.matches.every((match) => match.hasResult);
    });
  }

  @override
  Widget build(BuildContext context) {
    final plan = stage.qualificationPlan;
    if (plan == null || plan.extraCount == 0 || plan.extraGroups.isEmpty) {
      return const SizedBox.shrink();
    }

    final candidates = <BestOfCandidate>[];
    for (var groupIndex = 0; groupIndex < stage.groups.length; groupIndex++) {
      final groupNumber = groupIndex + 1;
      if (!plan.extraGroups.contains(groupNumber)) {
        continue;
      }

      final standings = standingsByGroup[stage.groups[groupIndex]] ?? const [];
      final candidateIndex = plan.extraRank - 1;
      if (candidateIndex >= 0 && candidateIndex < standings.length) {
        candidates.add(
          BestOfCandidate(
            groupName: stage.groups[groupIndex].name,
            groupNumber: groupNumber,
            place: plan.extraRank,
            standing: standings[candidateIndex],
          ),
        );
      }
    }

    candidates.sort(_compareCandidates);
    final allComplete = _allCandidateGroupsComplete(candidates);
    final qualifiedColor = allComplete
        ? const Color(0xFF0B6B45)
        : const Color(0xFFC8F7DC);

    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Beste ${plan.extraCount} der ${plan.extraRank}. Plaetze',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            'Vergleich aus ${_formatGroups(plan.extraGroups)}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowHeight: 34,
              dataRowMinHeight: 38,
              dataRowMaxHeight: 42,
              columns: const [
                DataColumn(label: Text('#')),
                DataColumn(label: Text('Gruppe')),
                DataColumn(label: Text('Spieler')),
                DataColumn(label: Text('Pkt')),
                DataColumn(label: Text('Legs')),
                DataColumn(label: Text('Diff')),
              ],
              rows: [
                for (var index = 0; index < candidates.length; index++)
                  DataRow(
                    color: WidgetStateProperty.resolveWith((states) {
                      return index < plan.extraCount ? qualifiedColor : null;
                    }),
                    cells: [
                      DataCell(Text('${index + 1}')),
                      DataCell(Text(candidates[index].groupName)),
                      DataCell(Text(candidates[index].standing.player.name)),
                      DataCell(Text('${candidates[index].standing.points}')),
                      DataCell(
                        Text(
                          '${candidates[index].standing.legsFor}:'
                          '${candidates[index].standing.legsAgainst}',
                        ),
                      ),
                      DataCell(
                        Text('${candidates[index].standing.legDifference}'),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatGroups(List<int> groups) {
    if (groups.length == 1) {
      return groupLabel(groups.first);
    }

    return groups.map(groupLabel).join(', ');
  }
}

class _KnockoutRunSection extends StatelessWidget {
  const _KnockoutRunSection({
    required this.stage,
    required this.qualifyingRank,
    required this.onEditResult,
    required this.canEditResults,
    required this.isEditMode,
    required this.canEditBracket,
    required this.onEditModeChanged,
    required this.onSwapSlot,
  });

  final KnockoutTournamentRunStage stage;
  final int qualifyingRank;
  final void Function(GroupMatch match) onEditResult;
  final bool canEditResults;
  final bool isEditMode;
  final bool canEditBracket;
  final ValueChanged<bool> onEditModeChanged;
  final void Function(int fromSlotIndex, int toSlotIndex) onSwapSlot;

  @override
  Widget build(BuildContext context) {
    return _StageSurface(
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
            _KnockoutBracketView(
              stage: stage,
              qualifyingRank: qualifyingRank,
              onEditResult: onEditResult,
              canEditResults: canEditResults,
              isEditMode: isEditMode && canEditBracket,
              onSwapSlot: onSwapSlot,
            ),
          if (stage.placementMatches.isNotEmpty) ...[
            const SizedBox(height: 14),
            _PlacementMatchesSection(
              matches: stage.placementMatches,
              qualifyingRank: qualifyingRank,
              onEditResult: onEditResult,
              canEditResults: canEditResults,
            ),
          ],
        ],
      ),
    );
  }

}

class _PlacementMatchesSection extends StatelessWidget {
  const _PlacementMatchesSection({
    required this.matches,
    required this.qualifyingRank,
    required this.onEditResult,
    required this.canEditResults,
  });

  final List<GroupMatch> matches;
  final int qualifyingRank;
  final void Function(GroupMatch match) onEditResult;
  final bool canEditResults;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Platzierungsspiele',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        for (final match in matches)
          _MatchResultTile(
            match: match,
            onEditResult: onEditResult,
            canEditResult: canEditResults,
            leadingLabel: match.label,
            qualificationLabel: _placementQualificationLabel(
              match.label,
              qualifyingRank,
            ),
          ),
      ],
    );
  }

  String? _placementQualificationLabel(String? label, int qualifyingRank) {
    if (label == 'Spiel um Platz 3') {
      if (qualifyingRank >= 4) return 'Platz 3-4 weiter';
      if (qualifyingRank >= 3) return 'Sieger weiter';
    }
    if (label?.startsWith('Platz 5 Halbfinale') ?? false) {
      if (qualifyingRank >= 8) return 'Platz 5-8 weiter';
      if (qualifyingRank >= 5) return 'relevant fuer Platz 5';
    }
    if (label == 'Spiel um Platz 5') {
      if (qualifyingRank >= 6) return 'Platz 5-6 weiter';
      if (qualifyingRank >= 5) return 'Sieger weiter';
    }
    if (label == 'Spiel um Platz 7') {
      if (qualifyingRank >= 8) return 'Platz 7-8 weiter';
      if (qualifyingRank >= 7) return 'Sieger weiter';
    }
    return null;
  }
}

class _KnockoutBracketView extends StatelessWidget {
  const _KnockoutBracketView({
    required this.stage,
    required this.qualifyingRank,
    required this.onEditResult,
    required this.canEditResults,
    this.isEditMode = false,
    this.onSwapSlot,
  });

  final KnockoutTournamentRunStage stage;
  final int qualifyingRank;
  final void Function(GroupMatch match) onEditResult;
  final bool canEditResults;
  final bool isEditMode;
  final void Function(int fromSlotIndex, int toSlotIndex)? onSwapSlot;

  @override
  Widget build(BuildContext context) {
    if (stage.eliminationLossLimit == 2) {
      return _DoubleEliminationBracketView(
        stage: stage,
        qualifyingRank: qualifyingRank,
        onEditResult: onEditResult,
        canEditResults: canEditResults,
        isEditMode: isEditMode,
        onSwapSlot: onSwapSlot,
      );
    }

    return _BracketTreeLayout(
      totalRounds: stage.rounds.length,
      columnWidth: 260,
      cardHeight: 204,
      firstRoundGap: 12,
      useBalancedColumnLayout: stage.eliminationLossLimit > 1,
      roundTitles: [
        for (var index = 0; index < stage.rounds.length; index++)
          stage.eliminationLossLimit == 2
              ? _doubleEliminationColumnTitle(stage.rounds[index])
              : stage.eliminationLossLimit > 1
                  ? _lossLevelColumnTitle(stage.rounds[index], index + 1)
                  : _bracketRoundTitle(index, stage.rounds.length),
      ],
      roundCards: [
        for (var roundIndex = 0; roundIndex < stage.rounds.length; roundIndex++)
          [
            for (
              var matchIndex = 0;
              matchIndex < stage.rounds[roundIndex].length;
              matchIndex++
            )
              _KnockoutBracketMatchCard(
                match: stage.rounds[roundIndex][matchIndex],
                matchNumber: matchIndex + 1,
                roundIndex: roundIndex,
                matchIndex: matchIndex,
                totalRounds: stage.rounds.length,
                qualifyingRank: qualifyingRank,
                onEditResult: onEditResult,
                canEditResult: canEditResults,
                isEditMode: isEditMode,
                onSwapSlot: onSwapSlot,
              ),
          ],
      ],
    );
  }
}

class _DoubleEliminationBracketView extends StatelessWidget {
  const _DoubleEliminationBracketView({
    required this.stage,
    required this.qualifyingRank,
    required this.onEditResult,
    required this.canEditResults,
    required this.isEditMode,
    this.onSwapSlot,
  });

  final KnockoutTournamentRunStage stage;
  final int qualifyingRank;
  final void Function(GroupMatch match) onEditResult;
  final bool canEditResults;
  final bool isEditMode;
  final void Function(int fromSlotIndex, int toSlotIndex)? onSwapSlot;

  @override
  Widget build(BuildContext context) {
    final winnersRounds = _doubleBracketRounds(_doubleWinnersPrefix);
    final losersRounds = _doubleBracketRounds(_doubleLosersPrefix);
    final finalMatches = [
      ..._matchesWithLabel(stage.rounds, _doubleGrandFinalLabel),
      ..._matchesWithLabel(stage.rounds, _doubleResetFinalLabel),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _BracketBandTitle(title: 'Winners Bracket'),
        const SizedBox(height: 8),
        _BracketTreeLayout(
          totalRounds: winnersRounds.length,
          columnWidth: 260,
          cardHeight: 204,
          firstRoundGap: 12,
          useBalancedColumnLayout: true,
          roundTitles: [
            for (var index = 0; index < winnersRounds.length; index++)
              _doubleWinnersLabel(index + 1),
          ],
          roundCards: [
            for (var roundIndex = 0; roundIndex < winnersRounds.length; roundIndex++)
              _matchCards(winnersRounds[roundIndex], roundIndex),
          ],
        ),
        const SizedBox(height: 18),
        _BracketBandTitle(title: 'Losers Bracket'),
        const SizedBox(height: 8),
        _BracketTreeLayout(
          totalRounds: losersRounds.length,
          columnWidth: 260,
          cardHeight: 204,
          firstRoundGap: 12,
          useBalancedColumnLayout: true,
          roundTitles: [
            for (var index = 0; index < losersRounds.length; index++)
              _doubleLosersLabel(index + 1),
          ],
          roundCards: [
            for (var roundIndex = 0; roundIndex < losersRounds.length; roundIndex++)
              _matchCards(losersRounds[roundIndex], roundIndex),
          ],
        ),
        const SizedBox(height: 18),
        _BracketBandTitle(title: 'Finale'),
        const SizedBox(height: 8),
        _BracketTreeLayout(
          totalRounds: finalMatches.isEmpty ? 0 : 1,
          columnWidth: 260,
          cardHeight: 204,
          firstRoundGap: 12,
          useBalancedColumnLayout: true,
          roundTitles: const ['Grand Final'],
          roundCards: [
            _matchCards(finalMatches, 0),
          ],
        ),
      ],
    );
  }

  List<List<GroupMatch>> _doubleBracketRounds(String prefix) {
    final highestRound = prefix == _doubleWinnersPrefix
        ? _doubleWinnersRoundCount(stage.rounds)
        : _doubleLosersRoundCount(stage.rounds);
    return [
      for (var roundNumber = 1; roundNumber <= highestRound; roundNumber++)
        _matchesWithLabel(
          stage.rounds,
          prefix == _doubleWinnersPrefix
              ? _doubleWinnersLabel(roundNumber)
              : _doubleLosersLabel(roundNumber),
        ),
    ];
  }

  List<Widget> _matchCards(List<GroupMatch> matches, int roundIndex) {
    return [
      for (var matchIndex = 0; matchIndex < matches.length; matchIndex++)
        _KnockoutBracketMatchCard(
          match: matches[matchIndex],
          matchNumber: matchIndex + 1,
          roundIndex: roundIndex,
          matchIndex: matchIndex,
          totalRounds: matches.length,
          qualifyingRank: qualifyingRank,
          onEditResult: onEditResult,
          canEditResult: canEditResults,
          isEditMode: isEditMode,
          onSwapSlot: onSwapSlot,
        ),
    ];
  }
}

class _BracketBandTitle extends StatelessWidget {
  const _BracketBandTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.bold,
      ),
    );
  }
}

String _bracketRoundTitle(int roundIndex, int totalRounds) {
  if (roundIndex == totalRounds - 1) {
    return 'Finale';
  }
  if (roundIndex == totalRounds - 2) {
    return 'Halbfinale';
  }
  return 'Runde ${roundIndex + 1}';
}

String _doubleEliminationColumnTitle(List<GroupMatch> matches) {
  final labels = [
    for (final match in matches)
      if (match.label != null) match.label!,
  ];
  if (labels.isEmpty) {
    return 'Runde';
  }
  final winnersLabels = labels
      .where((label) => label.startsWith(_doubleWinnersPrefix))
      .toList();
  final losersLabels = labels
      .where((label) => label.startsWith(_doubleLosersPrefix))
      .toList();
  if (winnersLabels.isNotEmpty && losersLabels.isNotEmpty) {
    return '${winnersLabels.first} / ${losersLabels.first}';
  }
  return labels.first;
}

String _lossLevelColumnTitle(List<GroupMatch> matches, int fallbackRound) {
  final labels = [
    for (final match in matches)
      if (match.label != null) match.label!,
  ];
  if (labels.isEmpty) {
    return 'Runde $fallbackRound';
  }
  final distinctLabels = <String>[];
  for (final label in labels) {
    if (!distinctLabels.contains(label)) {
      distinctLabels.add(label);
    }
  }
  if (distinctLabels.length == 1) {
    return distinctLabels.single;
  }
  return distinctLabels.join(' / ');
}

class _BracketTreeLayout extends StatelessWidget {
  const _BracketTreeLayout({
    required this.totalRounds,
    required this.roundTitles,
    required this.roundCards,
    required this.columnWidth,
    required this.cardHeight,
    required this.firstRoundGap,
    this.useBalancedColumnLayout = false,
  });

  static const double _headerHeight = 34;
  static const double _headerGap = 10;
  static const double _connectorWidth = 34;

  final int totalRounds;
  final List<String> roundTitles;
  final List<List<Widget>> roundCards;
  final double columnWidth;
  final double cardHeight;
  final double firstRoundGap;
  final bool useBalancedColumnLayout;

  double _columnContentHeight(int roundIndex) {
    final matchCount = roundCards[roundIndex].length;
    if (matchCount == 0) {
      return 0;
    }
    return matchCount * cardHeight + (matchCount - 1) * firstRoundGap;
  }

  double _contentHeight() {
    if (!useBalancedColumnLayout) {
      final firstRoundCount = roundCards.first.length;
      return firstRoundCount * cardHeight +
          (firstRoundCount - 1) * firstRoundGap;
    }

    var height = 0.0;
    for (var roundIndex = 0; roundIndex < roundCards.length; roundIndex++) {
      final columnHeight = _columnContentHeight(roundIndex);
      if (columnHeight > height) {
        height = columnHeight;
      }
    }
    return height;
  }

  double _centerY(int roundIndex, int matchIndex) {
    if (useBalancedColumnLayout) {
      final contentHeight = _contentHeight();
      final columnHeight = _columnContentHeight(roundIndex);
      final columnTop =
          _headerHeight + _headerGap + (contentHeight - columnHeight) / 2;
      return columnTop + matchIndex * (cardHeight + firstRoundGap) + cardHeight / 2;
    }

    final firstPitch = cardHeight + firstRoundGap;
    final span = 1 << roundIndex;
    final firstMatchIndex = matchIndex * span;
    final lastMatchIndex = firstMatchIndex + span - 1;
    final firstCenter =
        _headerHeight + _headerGap + firstMatchIndex * firstPitch + cardHeight / 2;
    final lastCenter =
        _headerHeight + _headerGap + lastMatchIndex * firstPitch + cardHeight / 2;
    return (firstCenter + lastCenter) / 2;
  }

  @override
  Widget build(BuildContext context) {
    if (totalRounds == 0 || roundCards.isEmpty) {
      return const SizedBox.shrink();
    }

    final height = _headerHeight + _headerGap + _contentHeight();
    final width =
        totalRounds * columnWidth + (totalRounds - 1) * _connectorWidth;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: width,
        height: height,
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _BracketConnectorPainter(
                  totalRounds: totalRounds,
                  roundCards: roundCards,
                  columnWidth: columnWidth,
                  connectorWidth: _connectorWidth,
                  cardHeight: cardHeight,
                  firstRoundGap: firstRoundGap,
                  headerHeight: _headerHeight,
                  headerGap: _headerGap,
                  useBalancedColumnLayout: useBalancedColumnLayout,
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
            ),
            for (var roundIndex = 0; roundIndex < totalRounds; roundIndex++)
              Positioned(
                left: roundIndex * (columnWidth + _connectorWidth),
                top: 0,
                width: columnWidth,
                height: _headerHeight,
                child: _BracketRoundTitle(title: roundTitles[roundIndex]),
              ),
            for (var roundIndex = 0; roundIndex < roundCards.length; roundIndex++)
              for (
                var matchIndex = 0;
                matchIndex < roundCards[roundIndex].length;
                matchIndex++
              )
                Positioned(
                  left: roundIndex * (columnWidth + _connectorWidth),
                  top: _centerY(roundIndex, matchIndex) - cardHeight / 2,
                  width: columnWidth,
                  height: cardHeight,
                  child: roundCards[roundIndex][matchIndex],
                ),
          ],
        ),
      ),
    );
  }
}

class _BracketRoundTitle extends StatelessWidget {
  const _BracketRoundTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        title,
        style: Theme.of(
          context,
        ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _BracketConnectorPainter extends CustomPainter {
  const _BracketConnectorPainter({
    required this.totalRounds,
    required this.roundCards,
    required this.columnWidth,
    required this.connectorWidth,
    required this.cardHeight,
    required this.firstRoundGap,
    required this.headerHeight,
    required this.headerGap,
    required this.useBalancedColumnLayout,
    required this.color,
  });

  final int totalRounds;
  final List<List<Widget>> roundCards;
  final double columnWidth;
  final double connectorWidth;
  final double cardHeight;
  final double firstRoundGap;
  final double headerHeight;
  final double headerGap;
  final bool useBalancedColumnLayout;
  final Color color;

  double _columnContentHeight(int roundIndex) {
    final matchCount = roundCards[roundIndex].length;
    if (matchCount == 0) {
      return 0;
    }
    return matchCount * cardHeight + (matchCount - 1) * firstRoundGap;
  }

  double _contentHeight() {
    if (!useBalancedColumnLayout) {
      final firstRoundCount = roundCards.first.length;
      return firstRoundCount * cardHeight +
          (firstRoundCount - 1) * firstRoundGap;
    }

    var height = 0.0;
    for (var roundIndex = 0; roundIndex < roundCards.length; roundIndex++) {
      final columnHeight = _columnContentHeight(roundIndex);
      if (columnHeight > height) {
        height = columnHeight;
      }
    }
    return height;
  }

  double _centerY(int roundIndex, int matchIndex) {
    if (useBalancedColumnLayout) {
      final contentHeight = _contentHeight();
      final columnHeight = _columnContentHeight(roundIndex);
      final columnTop = headerHeight + headerGap + (contentHeight - columnHeight) / 2;
      return columnTop + matchIndex * (cardHeight + firstRoundGap) + cardHeight / 2;
    }

    final firstPitch = cardHeight + firstRoundGap;
    final span = 1 << roundIndex;
    final firstMatchIndex = matchIndex * span;
    final lastMatchIndex = firstMatchIndex + span - 1;
    final firstCenter =
        headerHeight + headerGap + firstMatchIndex * firstPitch + cardHeight / 2;
    final lastCenter =
        headerHeight + headerGap + lastMatchIndex * firstPitch + cardHeight / 2;
    return (firstCenter + lastCenter) / 2;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    for (var roundIndex = 0; roundIndex < totalRounds - 1; roundIndex++) {
      for (
        var matchIndex = 0;
        matchIndex < roundCards[roundIndex].length;
        matchIndex++
      ) {
        final nextMatchIndex = matchIndex ~/ 2;
        if (nextMatchIndex >= roundCards[roundIndex + 1].length) {
          continue;
        }

        final startX = roundIndex * (columnWidth + connectorWidth) + columnWidth;
        final endX = (roundIndex + 1) * (columnWidth + connectorWidth);
        final midX = startX + connectorWidth / 2;
        final startY = _centerY(roundIndex, matchIndex);
        final endY = _centerY(roundIndex + 1, nextMatchIndex);

        final path = Path()
          ..moveTo(startX, startY)
          ..lineTo(midX, startY)
          ..lineTo(midX, endY)
          ..lineTo(endX, endY);
        canvas.drawPath(path, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BracketConnectorPainter oldDelegate) {
    return oldDelegate.totalRounds != totalRounds ||
        oldDelegate.roundCards != roundCards ||
        oldDelegate.columnWidth != columnWidth ||
        oldDelegate.connectorWidth != connectorWidth ||
        oldDelegate.cardHeight != cardHeight ||
        oldDelegate.firstRoundGap != firstRoundGap ||
        oldDelegate.useBalancedColumnLayout != useBalancedColumnLayout ||
        oldDelegate.color != color;
  }
}

class _KnockoutBracketMatchCard extends StatelessWidget {
  const _KnockoutBracketMatchCard({
    required this.match,
    required this.matchNumber,
    required this.roundIndex,
    required this.matchIndex,
    required this.totalRounds,
    required this.qualifyingRank,
    required this.onEditResult,
    required this.canEditResult,
    required this.isEditMode,
    this.onSwapSlot,
  });

  final GroupMatch match;
  final int matchNumber;
  final int roundIndex;
  final int matchIndex;
  final int totalRounds;
  final int qualifyingRank;
  final void Function(GroupMatch match) onEditResult;
  final bool canEditResult;
  final bool isEditMode;
  final void Function(int fromSlotIndex, int toSlotIndex)? onSwapSlot;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final winner = match.winner;
    final qualificationLabel = _bracketQualificationLabel();

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                Icons.account_tree_outlined,
                size: 16,
                color: colorScheme.primary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Spiel $matchNumber',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ),
              IconButton.filledTonal(
                constraints: const BoxConstraints.tightFor(
                  width: 36,
                  height: 36,
                ),
                padding: EdgeInsets.zero,
                onPressed: canEditResult && match.hasPlayers
                    ? () => onEditResult(match)
                    : null,
                icon: const Icon(Icons.edit_outlined, size: 18),
                tooltip: 'Ergebnis',
              ),
            ],
          ),
          const SizedBox(height: 8),
          _BracketPlayerSlot(
            player: match.homePlayer,
            score: match.homeLegs,
            isWinner: winner != null && winner == match.homePlayer,
            label: match.homePlayer == null && match.allowsBye
                ? 'Freilos'
                : null,
            slotIndex: matchIndex * 2,
            isEditable: isEditMode && roundIndex == 0,
            onSwapSlot: onSwapSlot,
          ),
          const SizedBox(height: 6),
          _BracketPlayerSlot(
            player: match.awayPlayer,
            score: match.awayLegs,
            isWinner: winner != null && winner == match.awayPlayer,
            label: match.awayPlayer == null && match.allowsBye
                ? 'Freilos'
                : null,
            slotIndex: matchIndex * 2 + 1,
            isEditable: isEditMode && roundIndex == 0,
            onSwapSlot: onSwapSlot,
          ),
          if (qualificationLabel != null) ...[
            const SizedBox(height: 8),
            _QualificationMarker(label: qualificationLabel),
          ],
        ],
      ),
    );
  }

  String? _bracketQualificationLabel() {
    if (roundIndex == totalRounds - 1) {
      return qualifyingRank >= 2 ? 'Platz 1-2 weiter' : 'Sieger weiter';
    }

    if (roundIndex == totalRounds - 2) {
      if (qualifyingRank >= 4) return 'Platz 1-4 weiter';
      if (qualifyingRank >= 3) return 'Verlierer spielt Platz 3';
      return 'Sieger weiter';
    }

    if (roundIndex == totalRounds - 3) {
      if (qualifyingRank >= 8) return 'Platz 1-8 weiter';
      if (qualifyingRank >= 5) return 'Verlierer spielt Platz 5';
      return 'Sieger weiter';
    }

    return qualifyingRank > 1 ? 'Sieger weiter' : null;
  }
}

class _BracketPlayerSlot extends StatelessWidget {
  const _BracketPlayerSlot({
    required this.player,
    required this.score,
    required this.isWinner,
    this.label,
    this.slotIndex,
    this.isEditable = false,
    this.onSwapSlot,
  });

  final TournamentPlayer? player;
  final int? score;
  final bool isWinner;
  final String? label;
  final int? slotIndex;
  final bool isEditable;
  final void Function(int fromSlotIndex, int toSlotIndex)? onSwapSlot;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isOpen = player == null;
    final displayLabel = label ?? player?.name ?? 'offen';

    final baseSlot = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: isWinner
            ? colorScheme.primaryContainer
            : isEditable
            ? colorScheme.secondaryContainer.withValues(alpha: 0.35)
            : colorScheme.surfaceContainerLowest,
        border: Border.all(
          color: isWinner
              ? colorScheme.primary
              : isEditable
              ? colorScheme.secondary
              : colorScheme.outlineVariant,
        ),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              displayLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isOpen ? colorScheme.onSurfaceVariant : null,
                fontWeight: isWinner ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            score == null ? '-' : '$score',
            style: TextStyle(
              color: isOpen ? colorScheme.onSurfaceVariant : null,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );

    Widget slot = baseSlot;
    if (isEditable && slotIndex != null) {
      slot = DragTarget<int>(
        onWillAcceptWithDetails: (details) => details.data != slotIndex,
        onAcceptWithDetails: (details) {
          onSwapSlot?.call(details.data, slotIndex!);
        },
        builder: (context, candidateData, rejectedData) {
          final isHovering = candidateData.isNotEmpty;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              boxShadow: isHovering
                  ? [
                      BoxShadow(
                        color: colorScheme.primary.withValues(alpha: 0.22),
                        blurRadius: 8,
                      ),
                    ]
                  : const [],
            ),
            child: baseSlot,
          );
        },
      );
    }

    if (isEditable && player != null && slotIndex != null) {
      return Draggable<int>(
        data: slotIndex!,
        feedback: Material(
          color: Colors.transparent,
          child: SizedBox(width: 220, child: slot),
        ),
        childWhenDragging: Opacity(opacity: 0.45, child: slot),
        child: slot,
      );
    }

    return slot;
  }
}

class _StageSurface extends StatelessWidget {
  const _StageSurface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: child,
    );
  }
}

class _GroupRunSection extends StatefulWidget {
  const _GroupRunSection({
    required this.group,
    required this.groupNumber,
    required this.qualificationPlan,
    required this.tieBreakers,
    required this.standings,
    required this.onEditResult,
    required this.canEditResults,
  });

  final TournamentGroup group;
  final int groupNumber;
  final QualificationPlan? qualificationPlan;
  final List<String> tieBreakers;
  final List<PlayerStanding> standings;
  final void Function(GroupMatch match) onEditResult;
  final bool canEditResults;

  @override
  State<_GroupRunSection> createState() => _GroupRunSectionState();
}

class _GroupRunSectionState extends State<_GroupRunSection> {
  bool _showMatches = false;

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
            widget.group.name,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          _StandingsTable(
            standings: widget.standings,
            group: widget.group,
            groupNumber: widget.groupNumber,
            qualificationPlan: widget.qualificationPlan,
            tieBreakers: widget.tieBreakers,
          ),
          const SizedBox(height: 16),
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () {
              setState(() {
                _showMatches = !_showMatches;
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                border: Border.all(color: colorScheme.outlineVariant),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    _showMatches
                        ? Icons.keyboard_arrow_down
                        : Icons.keyboard_arrow_right,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Spiele',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  Chip(label: Text('${widget.group.matches.length}')),
                ],
              ),
            ),
          ),
          if (_showMatches) ...[
            const SizedBox(height: 8),
            for (final match in widget.group.matches)
              _MatchResultTile(
                match: match,
                onEditResult: widget.onEditResult,
                canEditResult: widget.canEditResults,
                leadingLabel: match.isDecider ? match.label : null,
              ),
          ],
        ],
      ),
    );
  }
}

class _MatchResultTile extends StatelessWidget {
  const _MatchResultTile({
    required this.match,
    required this.onEditResult,
    required this.canEditResult,
    this.originLabel,
    this.leadingLabel,
    this.qualificationLabel,
  });

  final GroupMatch match;
  final void Function(GroupMatch match) onEditResult;
  final bool canEditResult;
  final String? originLabel;
  final String? leadingLabel;
  final String? qualificationLabel;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          SizedBox(
            width: leadingLabel == null ? 74 : 148,
            child: Text(
              leadingLabel ?? 'Runde ${match.round}',
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ),
          const SizedBox(width: 8),
          if (originLabel != null) ...[
            _MatchOriginChip(label: originLabel!),
            const SizedBox(width: 8),
          ],
          if (qualificationLabel != null) ...[
            _QualificationMarker(label: qualificationLabel!),
            const SizedBox(width: 8),
          ],
          Expanded(child: Text(match.homePlayer?.name ?? 'offen')),
          _ScoreBadge(
            match: match,
            onTap: canEditResult && match.hasPlayers
                ? () => onEditResult(match)
                : null,
          ),
          Expanded(
            child: Text(
              match.awayPlayer?.name ?? 'offen',
              textAlign: TextAlign.right,
            ),
          ),
          const SizedBox(width: 12),
          IconButton.filledTonal(
            onPressed: canEditResult && match.hasPlayers
                ? () => onEditResult(match)
                : null,
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Ergebnis',
          ),
        ],
      ),
    );
  }
}

class _QualificationMarker extends StatelessWidget {
  const _QualificationMarker({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    const backgroundColor = Color(0xFFC8F7DC);
    const borderColor = Color(0xFF14965F);
    const textColor = Color(0xFF0B6B45);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: textColor,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _MatchOriginChip extends StatelessWidget {
  const _MatchOriginChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      constraints: const BoxConstraints(minWidth: 76),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: colorScheme.onSecondaryContainer,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ScoreBadge extends StatelessWidget {
  const _ScoreBadge({required this.match, this.onTap});

  final GroupMatch match;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final badge = Container(
      width: match.isAnnulled ? 92 : 64,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: match.isAnnulled
            ? colorScheme.errorContainer
            : match.hasResult
            ? colorScheme.primaryContainer
            : colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        match.isAnnulled
            ? 'annulliert'
            : match.hasResult
            ? '${match.homeLegs}:${match.awayLegs}'
            : '-:-',
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
    );

    if (onTap == null) {
      return badge;
    }

    return Tooltip(
      message: 'Ergebnis eingeben',
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: badge,
      ),
    );
  }
}

class _StandingsTable extends StatelessWidget {
  const _StandingsTable({
    required this.standings,
    required this.group,
    required this.groupNumber,
    required this.qualificationPlan,
    required this.tieBreakers,
  });

  final List<PlayerStanding> standings;
  final TournamentGroup group;
  final int groupNumber;
  final QualificationPlan? qualificationPlan;
  final List<String> tieBreakers;

  bool get _allMatchesComplete {
    return group.matches.every((match) => match.hasResult);
  }

  bool _isFixedQualificationPlace(int place) {
    final plan = qualificationPlan;
    if (plan == null) {
      return false;
    }

    final fixedForGroup = groupNumber - 1 < plan.fixedByGroup.length
        ? plan.fixedByGroup[groupNumber - 1]
        : plan.fixedPerGroup;
    return place <= fixedForGroup;
  }

  bool _isBestOfCandidatePlace(int place) {
    final plan = qualificationPlan;
    if (plan == null) {
      return false;
    }

    return plan.extraCount > 0 &&
        place == plan.extraRank &&
        plan.extraGroups.contains(groupNumber);
  }

  int _qualificationPlacesInGroup() {
    final plan = qualificationPlan;
    if (plan == null) {
      return 0;
    }

    final fixedForGroup = groupNumber - 1 < plan.fixedByGroup.length
        ? plan.fixedByGroup[groupNumber - 1]
        : plan.fixedPerGroup;
    return fixedForGroup +
        (plan.extraGroups.contains(groupNumber) && plan.extraCount > 0 ? 1 : 0);
  }

  int _remainingMatchesFor(PlayerStanding standing) {
    return group.matches.where((match) {
      if (match.hasResult) {
        return false;
      }

      return match.homePlayer?.name == standing.player.name ||
          match.awayPlayer?.name == standing.player.name;
    }).length;
  }

  bool _isSureQualification(PlayerStanding standing, int place) {
    if (!_isFixedQualificationPlace(place)) {
      return false;
    }

    if (_allMatchesComplete) {
      return true;
    }

    final qualificationPlaces = _qualificationPlacesInGroup();
    if (qualificationPlaces < 1) {
      return false;
    }

    final possibleOvertakers = standings.where((otherStanding) {
      if (otherStanding.player.name == standing.player.name) {
        return false;
      }

      final maxPoints =
          otherStanding.points + (_remainingMatchesFor(otherStanding) * 3);
      if (maxPoints > standing.points) {
        return true;
      }
      if (maxPoints < standing.points) {
        return false;
      }

      return _compareStandingsForTable(otherStanding, standing) < 0;
    }).length;

    return possibleOvertakers < qualificationPlaces;
  }

  int _compareStandingsForTable(PlayerStanding a, PlayerStanding b) {
    for (final tieBreaker in tieBreakers) {
      final comparison = switch (tieBreaker) {
        'points' => b.points.compareTo(a.points),
        'legDifference' => b.legDifference.compareTo(a.legDifference),
        'legsFor' => b.legsFor.compareTo(a.legsFor),
        'headToHead' => _compareHeadToHeadForTable(a, b),
        _ => 0,
      };

      if (comparison != 0) {
        return comparison;
      }
    }

    return a.player.name.compareTo(b.player.name);
  }

  int _compareHeadToHeadForTable(PlayerStanding a, PlayerStanding b) {
    var aPoints = 0;
    var bPoints = 0;
    var aLegs = 0;
    var bLegs = 0;

    for (final match in group.matches.where(
      (match) => match.hasResult && !match.isDecider,
    )) {
      final home = match.homePlayer!;
      final away = match.awayPlayer!;
      final isDirectMatch =
          (home.name == a.player.name && away.name == b.player.name) ||
          (home.name == b.player.name && away.name == a.player.name);
      if (!isDirectMatch) {
        continue;
      }

      final aIsHome = home.name == a.player.name;
      final aMatchLegs = aIsHome ? match.homeLegs! : match.awayLegs!;
      final bMatchLegs = aIsHome ? match.awayLegs! : match.homeLegs!;
      aLegs += aMatchLegs;
      bLegs += bMatchLegs;

      if (aMatchLegs > bMatchLegs) {
        aPoints += 3;
      } else if (bMatchLegs > aMatchLegs) {
        bPoints += 3;
      } else {
        aPoints++;
        bPoints++;
      }
    }

    final pointCompare = bPoints.compareTo(aPoints);
    if (pointCompare != 0) return pointCompare;
    final diffCompare = (bLegs - aLegs).compareTo(aLegs - bLegs);
    if (diffCompare != 0) return diffCompare;
    return bLegs.compareTo(aLegs);
  }

  @override
  Widget build(BuildContext context) {
    final sureColor = const Color(0xFF0B6B45);
    final possibleColor = const Color(0xFFC8F7DC);
    final bestOfColor = const Color(0xFFFFE8A3);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowHeight: 36,
        dataRowMinHeight: 40,
        dataRowMaxHeight: 44,
        columns: const [
          DataColumn(label: Text('#')),
          DataColumn(label: Text('Spieler')),
          DataColumn(label: Text('Sp')),
          DataColumn(label: Text('S')),
          DataColumn(label: Text('U')),
          DataColumn(label: Text('N')),
          DataColumn(label: Text('Legs')),
          DataColumn(label: Text('Diff')),
          DataColumn(label: Text('Pkt')),
        ],
        rows: [
          for (var index = 0; index < standings.length; index++)
            DataRow(
              color: WidgetStateProperty.resolveWith((states) {
                final place = index + 1;
                if (_isFixedQualificationPlace(place)) {
                  return _isSureQualification(standings[index], place)
                      ? sureColor
                      : possibleColor;
                }

                if (_isBestOfCandidatePlace(place)) {
                  return bestOfColor;
                }

                return null;
              }),
              cells: [
                DataCell(
                  _StandingText(
                    '${index + 1}',
                    isDark: _isSureQualification(standings[index], index + 1),
                  ),
                ),
                DataCell(
                  _StandingText(
                    standings[index].player.name,
                    isDark: _isSureQualification(standings[index], index + 1),
                  ),
                ),
                DataCell(
                  _StandingText(
                    '${standings[index].played}',
                    isDark: _isSureQualification(standings[index], index + 1),
                  ),
                ),
                DataCell(
                  _StandingText(
                    '${standings[index].wins}',
                    isDark: _isSureQualification(standings[index], index + 1),
                  ),
                ),
                DataCell(
                  _StandingText(
                    '${standings[index].draws}',
                    isDark: _isSureQualification(standings[index], index + 1),
                  ),
                ),
                DataCell(
                  _StandingText(
                    '${standings[index].losses}',
                    isDark: _isSureQualification(standings[index], index + 1),
                  ),
                ),
                DataCell(
                  _StandingText(
                    '${standings[index].legsFor}:${standings[index].legsAgainst}',
                    isDark: _isSureQualification(standings[index], index + 1),
                  ),
                ),
                DataCell(
                  _StandingText(
                    '${standings[index].legDifference}',
                    isDark: _isSureQualification(standings[index], index + 1),
                  ),
                ),
                DataCell(
                  _StandingText(
                    '${standings[index].points}',
                    isDark: _isSureQualification(standings[index], index + 1),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _StandingText extends StatelessWidget {
  const _StandingText(this.text, {required this.isDark});

  final String text;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: isDark ? Colors.white : null,
        fontWeight: isDark ? FontWeight.w600 : null,
      ),
    );
  }
}

class _ResultDialog extends StatefulWidget {
  const _ResultDialog({required this.match});

  final GroupMatch match;

  @override
  State<_ResultDialog> createState() => _ResultDialogState();
}

class _ResultDialogState extends State<_ResultDialog> {
  late final TextEditingController _homeLegsController;
  late final TextEditingController _awayLegsController;

  @override
  void initState() {
    super.initState();
    _homeLegsController = TextEditingController(
      text: widget.match.homeLegs?.toString() ?? '',
    );
    _awayLegsController = TextEditingController(
      text: widget.match.awayLegs?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _homeLegsController.dispose();
    _awayLegsController.dispose();
    super.dispose();
  }

  void _save() {
    final homeLegs = int.tryParse(_homeLegsController.text);
    final awayLegs = int.tryParse(_awayLegsController.text);
    if (homeLegs == null || awayLegs == null || homeLegs < 0 || awayLegs < 0) {
      return;
    }
    if (widget.match.isDecider && homeLegs == awayLegs) {
      return;
    }

    Navigator.of(
      context,
    ).pop(MatchResult(homeLegs: homeLegs, awayLegs: awayLegs));
  }

  void _annul() {
    Navigator.of(context).pop(const MatchResult.annulled());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Ergebnis eingeben'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${widget.match.homePlayer?.name ?? 'offen'} vs '
            '${widget.match.awayPlayer?.name ?? 'offen'}',
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  key: const ValueKey('home-legs-field'),
                  controller: _homeLegsController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    labelText: widget.match.homePlayer?.name ?? 'offen',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  key: const ValueKey('away-legs-field'),
                  controller: _awayLegsController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    labelText: widget.match.awayPlayer?.name ?? 'offen',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton.icon(
          onPressed: _annul,
          icon: const Icon(Icons.block_outlined),
          label: const Text('Spiel annullieren'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Abbrechen'),
        ),
        FilledButton(onPressed: _save, child: const Text('Speichern')),
      ],
    );
  }
}

