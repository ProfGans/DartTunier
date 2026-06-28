part of '../../../../tournament_workspace.dart';

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
              placementMatches: group.placementMatches,
              qualifyingRank: qualifyingRank,
              onEditResult: onEditResult,
              canEditResults: canEditResults,
            ),
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
              placementMatches: stage.placementMatches,
              qualifyingRank: qualifyingRank,
              onEditResult: onEditResult,
              canEditResults: canEditResults,
              isEditMode: isEditMode && canEditBracket,
              onSwapSlot: onSwapSlot,
            ),
        ],
      ),
    );
  }

}

class _KnockoutBracketView extends StatelessWidget {
  const _KnockoutBracketView({
    required this.stage,
    required this.qualifyingRank,
    required this.onEditResult,
    required this.canEditResults,
    this.placementMatches = const [],
    this.isEditMode = false,
    this.onSwapSlot,
  });

  final KnockoutTournamentRunStage stage;
  final List<GroupMatch> placementMatches;
  final int qualifyingRank;
  final void Function(GroupMatch match) onEditResult;
  final bool canEditResults;
  final bool isEditMode;
  final void Function(int fromSlotIndex, int toSlotIndex)? onSwapSlot;

  @override
  Widget build(BuildContext context) {
    if (stage.eliminationLossLimit == 2) {
      final matchNumbers = _stageMatchNumbers(stage.rounds);
      final sourceLabels = _stageSourceLabels(stage, matchNumbers);
      final sourceMatches = _stageSourceMatches(stage);
      return _DoubleEliminationBracketView(
        stage: stage,
        matchNumbers: matchNumbers,
        sourceLabels: sourceLabels,
        sourceMatches: sourceMatches,
        qualifyingRank: qualifyingRank,
        onEditResult: onEditResult,
        canEditResults: canEditResults,
        isEditMode: isEditMode,
        onSwapSlot: onSwapSlot,
      );
    }
    if (stage.eliminationLossLimit == 3) {
      final matchNumbers = _stageMatchNumbers(stage.rounds);
      final sourceLabels = _stageSourceLabels(stage, matchNumbers);
      final sourceMatches = _stageSourceMatches(stage);
      return _TripleEliminationBracketView(
        stage: stage,
        matchNumbers: matchNumbers,
        sourceLabels: sourceLabels,
        sourceMatches: sourceMatches,
        qualifyingRank: qualifyingRank,
        onEditResult: onEditResult,
        canEditResults: canEditResults,
        isEditMode: isEditMode,
        onSwapSlot: onSwapSlot,
      );
    }

    final displayRounds = _singleKnockoutRoundsWithPlacement(
      stage.rounds,
      placementMatches,
    );
    final matchNumbers = _stageMatchNumbers(displayRounds);
    final sourceLabels = {
      ..._singleKnockoutSourceLabels(displayRounds, matchNumbers),
      ..._singleKnockoutPlacementSourceLabels(
        stage.rounds,
        placementMatches,
        matchNumbers,
      ),
    };
    final sourceMatches = {
      ..._singleKnockoutSourceMatches(displayRounds),
      ..._singleKnockoutPlacementSourceMatches(stage.rounds, placementMatches),
    };

    return _BracketTreeLayout(
      totalRounds: displayRounds.length,
      columnWidth: 260,
      cardHeight: 204,
      firstRoundGap: 12,
      useBalancedColumnLayout: stage.eliminationLossLimit > 1,
      roundMatches: displayRounds,
      sourceMatches: sourceMatches,
      roundTitles: [
        for (var index = 0; index < displayRounds.length; index++)
          stage.eliminationLossLimit == 2
              ? _doubleEliminationColumnTitle(displayRounds[index])
              : stage.eliminationLossLimit > 1
                  ? _lossLevelColumnTitle(displayRounds[index], index + 1)
                  : _bracketRoundTitle(index, displayRounds.length),
      ],
      roundCards: [
        for (var roundIndex = 0; roundIndex < displayRounds.length; roundIndex++)
          [
            for (
              var matchIndex = 0;
              matchIndex < displayRounds[roundIndex].length;
              matchIndex++
            )
              _KnockoutBracketMatchCard(
                match: displayRounds[roundIndex][matchIndex],
                matchNumber:
                    matchNumbers[displayRounds[roundIndex][matchIndex]] ??
                    matchIndex + 1,
                homeSourceLabel:
                    sourceLabels[displayRounds[roundIndex][matchIndex]]?.first,
                awaySourceLabel:
                    sourceLabels[displayRounds[roundIndex][matchIndex]]?.second,
                roundIndex: roundIndex,
                matchIndex: matchIndex,
                totalRounds: displayRounds.length,
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

List<List<GroupMatch>> _singleKnockoutRoundsWithPlacement(
  List<List<GroupMatch>> rounds,
  List<GroupMatch> placementMatches,
) {
  if (placementMatches.isEmpty) {
    return rounds;
  }
  if (rounds.isEmpty) {
    return [placementMatches];
  }

  final displayRounds = [
    for (final round in rounds) List<GroupMatch>.from(round),
  ];
  final fifthSemis = placementMatches
      .where((match) => match.label?.startsWith('Platz 5 Halbfinale') ?? false)
      .toList();
  final finalColumnMatches = placementMatches
      .where((match) =>
          match.label == 'Spiel um Platz 3' ||
          match.label == 'Spiel um Platz 5' ||
          match.label == 'Spiel um Platz 7')
      .toList();

  if (fifthSemis.isNotEmpty) {
    final targetIndex = displayRounds.length >= 2
        ? displayRounds.length - 2
        : displayRounds.length - 1;
    displayRounds[targetIndex].addAll(fifthSemis);
  }
  if (finalColumnMatches.isNotEmpty) {
    displayRounds.last.addAll(finalColumnMatches);
  }

  return displayRounds;
}

Map<GroupMatch, int> _stageMatchNumbers(List<List<GroupMatch>> rounds) {
  final numbers = <GroupMatch, int>{};
  var nextNumber = 1;
  for (final round in rounds) {
    for (final match in round) {
      if (match.label == _autoAdvanceLabel) {
        continue;
      }
      numbers[match] = nextNumber;
      nextNumber++;
    }
  }
  return numbers;
}

Map<GroupMatch, ({String? first, String? second})> _stageSourceLabels(
  KnockoutTournamentRunStage stage,
  Map<GroupMatch, int> matchNumbers,
) {
  if (stage.eliminationLossLimit == 2) {
    return _doubleSourceLabels(stage.rounds, matchNumbers);
  }
  if (stage.eliminationLossLimit == 3) {
    return _lossLevelSourceLabels(stage.rounds, matchNumbers);
  }
  return _singleKnockoutSourceLabels(stage.rounds, matchNumbers);
}

Map<GroupMatch, ({GroupMatch? first, GroupMatch? second})> _stageSourceMatches(
  KnockoutTournamentRunStage stage,
) {
  if (stage.eliminationLossLimit == 2) {
    return _doubleSourceMatches(stage.rounds);
  }
  if (stage.eliminationLossLimit == 3) {
    return _lossLevelSourceMatches(stage.rounds);
  }
  return _singleKnockoutSourceMatches(stage.rounds);
}

Map<GroupMatch, ({String? first, String? second})> _singleKnockoutSourceLabels(
  List<List<GroupMatch>> rounds,
  Map<GroupMatch, int> matchNumbers,
) {
  final labels = <GroupMatch, ({String? first, String? second})>{};
  for (var roundIndex = 1; roundIndex < rounds.length; roundIndex++) {
    for (var matchIndex = 0; matchIndex < rounds[roundIndex].length; matchIndex++) {
      final firstSource = rounds[roundIndex - 1][matchIndex * 2];
      final secondSource = rounds[roundIndex - 1][matchIndex * 2 + 1];
      labels[rounds[roundIndex][matchIndex]] = (
        first: 'Gewinner Spiel ${matchNumbers[firstSource]}',
        second: 'Gewinner Spiel ${matchNumbers[secondSource]}',
      );
    }
  }
  return labels;
}

Map<GroupMatch, ({GroupMatch? first, GroupMatch? second})>
    _singleKnockoutSourceMatches(List<List<GroupMatch>> rounds) {
  final sources = <GroupMatch, ({GroupMatch? first, GroupMatch? second})>{};
  for (var roundIndex = 1; roundIndex < rounds.length; roundIndex++) {
    for (var matchIndex = 0;
        matchIndex < rounds[roundIndex].length;
        matchIndex++) {
      final previous = rounds[roundIndex - 1];
      sources[rounds[roundIndex][matchIndex]] = (
        first: matchIndex * 2 < previous.length
            ? previous[matchIndex * 2]
            : null,
        second: matchIndex * 2 + 1 < previous.length
            ? previous[matchIndex * 2 + 1]
            : null,
      );
    }
  }
  return sources;
}

Map<GroupMatch, ({String? first, String? second})>
    _singleKnockoutPlacementSourceLabels(
  List<List<GroupMatch>> rounds,
  List<GroupMatch> placementMatches,
  Map<GroupMatch, int> matchNumbers,
) {
  final sources = _singleKnockoutPlacementSourceMatches(
    rounds,
    placementMatches,
  );
  return {
    for (final entry in sources.entries)
      entry.key: (
        first: _placementSourceLabel(entry.key, entry.value.first, matchNumbers),
        second:
            _placementSourceLabel(entry.key, entry.value.second, matchNumbers),
      ),
  };
}

String? _placementSourceLabel(
  GroupMatch placementMatch,
  GroupMatch? sourceMatch,
  Map<GroupMatch, int> matchNumbers,
) {
  if (sourceMatch == null) {
    return null;
  }
  final label = placementMatch.label;
  if (label == 'Spiel um Platz 5') {
    return _winnerSourceLabel(sourceMatch, matchNumbers);
  }
  return _loserSourceLabel(sourceMatch, matchNumbers);
}

Map<GroupMatch, ({GroupMatch? first, GroupMatch? second})>
    _singleKnockoutPlacementSourceMatches(
  List<List<GroupMatch>> rounds,
  List<GroupMatch> placementMatches,
) {
  final sources = <GroupMatch, ({GroupMatch? first, GroupMatch? second})>{};
  if (placementMatches.isEmpty) {
    return sources;
  }

  final thirdPlaceMatches = placementMatches
      .where((match) => match.label == 'Spiel um Platz 3')
      .toList();
  if (thirdPlaceMatches.isNotEmpty && rounds.length >= 2) {
    final semifinals = rounds.last.length >= 2
        ? rounds.last
        : rounds[rounds.length - 2];
    sources[thirdPlaceMatches.first] = (
      first: semifinals.isNotEmpty ? semifinals[0] : null,
      second: semifinals.length > 1 ? semifinals[1] : null,
    );
  }

  final fifthSemis = placementMatches
      .where((match) => match.label?.startsWith('Platz 5 Halbfinale') ?? false)
      .toList();
  if (fifthSemis.isNotEmpty) {
    final quarterfinals = rounds.last.length >= 4
        ? rounds.last
        : rounds.length >= 3
        ? rounds[rounds.length - 3]
        : const <GroupMatch>[];
    for (var index = 0; index < fifthSemis.length; index++) {
      final sourceIndex = index * 2;
      sources[fifthSemis[index]] = (
        first: sourceIndex < quarterfinals.length
            ? quarterfinals[sourceIndex]
            : null,
        second: sourceIndex + 1 < quarterfinals.length
            ? quarterfinals[sourceIndex + 1]
            : null,
      );
    }
  }

  final fifthPlaceMatches = placementMatches
      .where((match) => match.label == 'Spiel um Platz 5')
      .toList();
  if (fifthPlaceMatches.isNotEmpty) {
    sources[fifthPlaceMatches.first] = (
      first: fifthSemis.isNotEmpty ? fifthSemis[0] : null,
      second: fifthSemis.length > 1 ? fifthSemis[1] : null,
    );
  }

  final seventhPlaceMatches = placementMatches
      .where((match) => match.label == 'Spiel um Platz 7')
      .toList();
  if (seventhPlaceMatches.isNotEmpty) {
    sources[seventhPlaceMatches.first] = (
      first: fifthSemis.isNotEmpty ? fifthSemis[0] : null,
      second: fifthSemis.length > 1 ? fifthSemis[1] : null,
    );
  }

  return sources;
}

Map<GroupMatch, ({String? first, String? second})> _doubleSourceLabels(
  List<List<GroupMatch>> rounds,
  Map<GroupMatch, int> matchNumbers,
) {
  final labels = <GroupMatch, ({String? first, String? second})>{};
  final winnersRoundCount = _doubleWinnersRoundCount(rounds);
  final losersRoundCount = _doubleLosersRoundCount(rounds);

  for (var roundNumber = 2; roundNumber <= winnersRoundCount; roundNumber++) {
    final previous = _doubleWinnersRoundMatches(
      rounds,
      roundNumber - 1,
      includeAutoAdvances: roundNumber == 2,
    );
    final current = _doubleWinnersRoundMatches(rounds, roundNumber);
    for (var index = 0; index < current.length; index++) {
      final firstSource = index * 2 < previous.length
          ? previous[index * 2]
          : null;
      final secondSource = index * 2 + 1 < previous.length
          ? previous[index * 2 + 1]
          : null;
      labels[current[index]] = (
        first: _winnerSourceLabel(firstSource, matchNumbers),
        second: _winnerSourceLabel(secondSource, matchNumbers),
      );
    }
  }

  final firstWinners = _doubleWinnersRoundMatches(
    rounds,
    1,
    includeAutoAdvances: true,
  );
  final firstLosers = _matchesWithLabel(rounds, _doubleLosersLabel(1));
  for (final match in firstLosers) {
    labels[match] = (first: null, second: null);
  }
  final firstWinnersWithLoserSource = [
    for (final match in firstWinners)
      if (match.label != _autoAdvanceLabel) match,
  ];
  if (firstLosers.isNotEmpty &&
      firstWinnersWithLoserSource.length <= firstLosers.length) {
    for (var index = 0; index < firstWinnersWithLoserSource.length; index++) {
      final targetIndex =
          (index * firstLosers.length) ~/ firstWinnersWithLoserSource.length;
      labels[firstLosers[targetIndex]] = (
        first: _loserSourceLabel(
          firstWinnersWithLoserSource[index],
          matchNumbers,
        ),
        second: null,
      );
    }
  } else {
    for (var index = 0; index < firstWinnersWithLoserSource.length; index++) {
      final targetIndex = index ~/ 2;
      if (targetIndex >= firstLosers.length) {
        break;
      }
      final current =
          labels[firstLosers[targetIndex]] ?? (first: null, second: null);
      labels[firstLosers[targetIndex]] = index.isEven
          ? (
              first: _loserSourceLabel(
                firstWinnersWithLoserSource[index],
                matchNumbers,
              ),
              second: current.second,
            )
          : (
              first: current.first,
              second: _loserSourceLabel(
                firstWinnersWithLoserSource[index],
                matchNumbers,
              ),
            );
    }
  }

  for (var roundNumber = 2; roundNumber <= losersRoundCount; roundNumber++) {
    final current = _matchesWithLabel(rounds, _doubleLosersLabel(roundNumber));
    final previousLosers = _matchesWithLabel(rounds, _doubleLosersLabel(roundNumber - 1));
    final incomingWinnersRound = roundNumber == losersRoundCount
        ? winnersRoundCount
        : ((roundNumber + 2) ~/ 2);
    final incomingWinners = _matchesWithLabel(
      rounds,
      _doubleWinnersLabel(incomingWinnersRound),
    );
    for (var index = 0; index < current.length; index++) {
      final previousIndex = previousLosers.length == current.length
          ? index
          : index * 2;
      final firstSource = previousIndex < previousLosers.length
          ? previousLosers[previousIndex]
          : null;
      final secondSource = previousLosers.length == current.length
          ? (index < incomingWinners.length ? incomingWinners[index] : null)
          : (previousIndex + 1 < previousLosers.length
                ? previousLosers[previousIndex + 1]
                : null);
      labels[current[index]] = (
        first: _winnerSourceLabel(firstSource, matchNumbers),
        second: previousLosers.length == current.length
            ? _loserSourceLabel(secondSource, matchNumbers)
            : _winnerSourceLabel(secondSource, matchNumbers),
      );
    }
  }

  final grandFinal = _matchesWithLabel(rounds, _doubleGrandFinalLabel);
  if (grandFinal.isNotEmpty) {
    final winnersFinal = _doubleWinnersRoundMatches(rounds, winnersRoundCount);
    final losersFinal = _matchesWithLabel(rounds, _doubleLosersLabel(losersRoundCount));
    labels[grandFinal.first] = (
      first: winnersFinal.isEmpty
          ? null
          : _winnerSourceLabel(winnersFinal.first, matchNumbers),
      second: losersFinal.isEmpty
          ? null
          : _winnerSourceLabel(losersFinal.first, matchNumbers),
    );
  }

  return labels;
}

Map<GroupMatch, ({GroupMatch? first, GroupMatch? second})> _doubleSourceMatches(
  List<List<GroupMatch>> rounds,
) {
  final sources = <GroupMatch, ({GroupMatch? first, GroupMatch? second})>{};
  final winnersRoundCount = _doubleWinnersRoundCount(rounds);
  final losersRoundCount = _doubleLosersRoundCount(rounds);

  for (var roundNumber = 2; roundNumber <= winnersRoundCount; roundNumber++) {
    final previous = _doubleWinnersRoundMatches(
      rounds,
      roundNumber - 1,
      includeAutoAdvances: roundNumber == 2,
    );
    final current = _doubleWinnersRoundMatches(rounds, roundNumber);
    for (var index = 0; index < current.length; index++) {
      sources[current[index]] = (
        first: index * 2 < previous.length ? previous[index * 2] : null,
        second: index * 2 + 1 < previous.length
            ? previous[index * 2 + 1]
            : null,
      );
    }
  }

  final firstWinners = _doubleWinnersRoundMatches(
    rounds,
    1,
    includeAutoAdvances: true,
  );
  final firstLosers = _matchesWithLabel(rounds, _doubleLosersLabel(1));
  for (final match in firstLosers) {
    sources[match] = (first: null, second: null);
  }
  final firstWinnersWithLoserSource = [
    for (final match in firstWinners)
      if (match.label != _autoAdvanceLabel) match,
  ];
  if (firstLosers.isNotEmpty &&
      firstWinnersWithLoserSource.length <= firstLosers.length) {
    for (var index = 0; index < firstWinnersWithLoserSource.length; index++) {
      final targetIndex =
          (index * firstLosers.length) ~/ firstWinnersWithLoserSource.length;
      sources[firstLosers[targetIndex]] = (
        first: firstWinnersWithLoserSource[index],
        second: null,
      );
    }
  } else {
    for (var index = 0; index < firstWinnersWithLoserSource.length; index++) {
      final targetIndex = index ~/ 2;
      if (targetIndex >= firstLosers.length) {
        break;
      }
      final current =
          sources[firstLosers[targetIndex]] ?? (first: null, second: null);
      sources[firstLosers[targetIndex]] = index.isEven
          ? (first: firstWinnersWithLoserSource[index], second: current.second)
          : (first: current.first, second: firstWinnersWithLoserSource[index]);
    }
  }

  for (var roundNumber = 2; roundNumber <= losersRoundCount; roundNumber++) {
    final current = _matchesWithLabel(rounds, _doubleLosersLabel(roundNumber));
    final previousLosers =
        _matchesWithLabel(rounds, _doubleLosersLabel(roundNumber - 1));
    final incomingWinnersRound =
        roundNumber == losersRoundCount ? winnersRoundCount : ((roundNumber + 2) ~/ 2);
    final incomingWinners = _matchesWithLabel(
      rounds,
      _doubleWinnersLabel(incomingWinnersRound),
    );
    for (var index = 0; index < current.length; index++) {
      final previousIndex =
          previousLosers.length == current.length ? index : index * 2;
      sources[current[index]] = (
        first: previousIndex < previousLosers.length
            ? previousLosers[previousIndex]
            : null,
        second: previousLosers.length == current.length
            ? (index < incomingWinners.length ? incomingWinners[index] : null)
            : (previousIndex + 1 < previousLosers.length
                ? previousLosers[previousIndex + 1]
                : null),
      );
    }
  }

  final grandFinal = _matchesWithLabel(rounds, _doubleGrandFinalLabel);
  if (grandFinal.isNotEmpty) {
    final winnersFinal = _doubleWinnersRoundMatches(rounds, winnersRoundCount);
    final losersFinal =
        _matchesWithLabel(rounds, _doubleLosersLabel(losersRoundCount));
    sources[grandFinal.first] = (
      first: winnersFinal.isEmpty ? null : winnersFinal.first,
      second: losersFinal.isEmpty ? null : losersFinal.first,
    );
  }

  return sources;
}

String? _winnerSourceLabel(
  GroupMatch? match,
  Map<GroupMatch, int> matchNumbers,
) {
  if (match == null) {
    return null;
  }
  if (match.label == _autoAdvanceLabel) {
    return match.winner?.name ?? _autoAdvanceLabel;
  }
  final winner = match.winner;
  if (winner != null) {
    return winner.name;
  }
  final number = matchNumbers[match];
  return number == null ? null : 'Gewinner Spiel $number';
}

String? _loserSourceLabel(
  GroupMatch? match,
  Map<GroupMatch, int> matchNumbers,
) {
  if (match == null || match.label == _autoAdvanceLabel) {
    return null;
  }
  final loser = match.loser;
  if (loser != null) {
    return loser.name;
  }
  final number = matchNumbers[match];
  return number == null ? null : 'Verlierer Spiel $number';
}

Map<GroupMatch, ({String? first, String? second})> _lossLevelSourceLabels(
  List<List<GroupMatch>> rounds,
  Map<GroupMatch, int> matchNumbers,
) {
  final labels = <GroupMatch, ({String? first, String? second})>{};
  final sourceEdges = _lossLevelSourceEdges(rounds);
  for (final entry in sourceEdges.entries) {
    labels[entry.key] = (
      first: _sourceEdgeLabel(entry.value.first, matchNumbers),
      second: _sourceEdgeLabel(entry.value.second, matchNumbers),
    );
  }
  return labels;
}

Map<GroupMatch, ({GroupMatch? first, GroupMatch? second})>
    _lossLevelSourceMatches(List<List<GroupMatch>> rounds) {
  final edges = _lossLevelSourceEdges(rounds);
  return {
    for (final entry in edges.entries)
      entry.key: (
        first: entry.value.first?.match,
        second: entry.value.second?.match,
      ),
  };
}

Map<GroupMatch, ({_SourceEdge? first, _SourceEdge? second})>
    _lossLevelSourceEdges(List<List<GroupMatch>> rounds) {
  final sources = <GroupMatch, ({_SourceEdge? first, _SourceEdge? second})>{};
  for (var lossCount = 0; lossCount < 3; lossCount++) {
    final roundCount = _lossLevelRoundCount(rounds, lossCount);
    for (var roundNumber = 2; roundNumber <= roundCount; roundNumber++) {
      final previous = lossCount == 0 && roundNumber == 2 && rounds.isNotEmpty
          ? rounds.first
          : _matchesWithLabel(rounds, _lossLevelMatchLabel(lossCount, roundNumber - 1));
      final current = _matchesWithLabel(
        rounds,
        _lossLevelMatchLabel(lossCount, roundNumber),
      );
      for (var index = 0; index < current.length; index++) {
        final currentSources = sources[current[index]] ?? (first: null, second: null);
        final previousIndex = previous.length == current.length ? index : index * 2;
        sources[current[index]] = previous.length == current.length
            ? (
                first: previousIndex < previous.length
                    ? _SourceEdge.winner(previous[previousIndex])
                    : null,
                second: currentSources.second,
              )
            : (
                first: previousIndex < previous.length
                    ? _SourceEdge.winner(previous[previousIndex])
                    : null,
                second: previousIndex + 1 < previous.length
                    ? _SourceEdge.winner(previous[previousIndex + 1])
                    : null,
              );
      }
    }
  }

  for (var sourceLossCount = 0; sourceLossCount < 2; sourceLossCount++) {
    final targetLossCount = sourceLossCount + 1;
    final sourceRoundCount = _lossLevelRoundCount(rounds, sourceLossCount);
    final targetRoundCount = _lossLevelRoundCount(rounds, targetLossCount);
    for (var roundNumber = 1; roundNumber <= sourceRoundCount; roundNumber++) {
      final sourceRound = sourceLossCount == 0 && roundNumber == 1 && rounds.isNotEmpty
          ? rounds.first
          : _matchesWithLabel(rounds, _lossLevelMatchLabel(sourceLossCount, roundNumber));
      final targetRoundNumber = roundNumber == 1
          ? 1
          : roundNumber == sourceRoundCount
              ? targetRoundCount
              : roundNumber * 2 - 2;
      final targetRound = _matchesWithLabel(
        rounds,
        _lossLevelMatchLabel(targetLossCount, targetRoundNumber),
      );
      if (sourceRound.isEmpty || targetRound.isEmpty) {
        continue;
      }

      if (roundNumber == 1 && sourceRound.length <= targetRound.length) {
        final droppingSources = [
          for (final match in sourceRound)
            if (match.label != _autoAdvanceLabel) match,
        ];
        if (droppingSources.isEmpty) {
          continue;
        }
        for (var index = 0; index < droppingSources.length; index++) {
          final targetIndex =
              (index * targetRound.length) ~/ droppingSources.length;
          sources[targetRound[targetIndex]] = (
            first: _SourceEdge.loser(droppingSources[index]),
            second: sources[targetRound[targetIndex]]?.second,
          );
        }
        continue;
      }

      for (var index = 0; index < sourceRound.length; index++) {
        final targetIndex = roundNumber == 1 ? index ~/ 2 : index;
        if (targetIndex >= targetRound.length) {
          break;
        }
        final currentSources = sources[targetRound[targetIndex]] ?? (first: null, second: null);
        sources[targetRound[targetIndex]] = index.isEven && roundNumber == 1
            ? (
                first: _SourceEdge.loser(sourceRound[index]),
                second: currentSources.second,
              )
            : (
                first: currentSources.first,
                second: _SourceEdge.loser(sourceRound[index]),
              );
      }
    }
  }

  final finalMatches = _matchesWithLabel(rounds, _tripleFinalLabel);
  if (finalMatches.isNotEmpty) {
    final zeroFinal = _matchesWithLabel(
      rounds,
      _lossLevelMatchLabel(0, _lossLevelRoundCount(rounds, 0)),
    );
    final twoLossFinal = _matchesWithLabel(
      rounds,
      _lossLevelMatchLabel(2, _lossLevelRoundCount(rounds, 2)),
    );
    sources[finalMatches.first] = (
      first: zeroFinal.isEmpty ? null : _SourceEdge.winner(zeroFinal.first),
      second: twoLossFinal.isEmpty ? null : _SourceEdge.winner(twoLossFinal.first),
    );
  }

  return sources;
}

String? _sourceEdgeLabel(
  _SourceEdge? edge,
  Map<GroupMatch, int> matchNumbers,
) {
  if (edge == null) {
    return null;
  }
  return edge.usesLoser
      ? _loserSourceLabel(edge.match, matchNumbers)
      : _winnerSourceLabel(edge.match, matchNumbers);
}

class _SourceEdge {
  const _SourceEdge.winner(this.match) : usesLoser = false;
  const _SourceEdge.loser(this.match) : usesLoser = true;

  final GroupMatch match;
  final bool usesLoser;
}

class _DoubleEliminationBracketView extends StatelessWidget {
  const _DoubleEliminationBracketView({
    required this.stage,
    required this.matchNumbers,
    required this.sourceLabels,
    required this.sourceMatches,
    required this.qualifyingRank,
    required this.onEditResult,
    required this.canEditResults,
    required this.isEditMode,
    this.onSwapSlot,
  });

  final KnockoutTournamentRunStage stage;
  final Map<GroupMatch, int> matchNumbers;
  final Map<GroupMatch, ({String? first, String? second})> sourceLabels;
  final Map<GroupMatch, ({GroupMatch? first, GroupMatch? second})> sourceMatches;
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
          roundMatches: winnersRounds,
          sourceMatches: sourceMatches,
          roundTitles: [
            for (var index = 0; index < winnersRounds.length; index++)
              _bracketRoundTitle(index, winnersRounds.length),
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
          roundMatches: losersRounds,
          sourceMatches: sourceMatches,
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
          roundMatches: [finalMatches],
          sourceMatches: sourceMatches,
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
        prefix == _doubleWinnersPrefix
            ? _doubleWinnersRoundMatches(stage.rounds, roundNumber)
            : _matchesWithLabel(stage.rounds, _doubleLosersLabel(roundNumber)),
    ];
  }

  List<Widget> _matchCards(List<GroupMatch> matches, int roundIndex) {
    return [
      for (var matchIndex = 0; matchIndex < matches.length; matchIndex++)
        _KnockoutBracketMatchCard(
          match: matches[matchIndex],
          matchNumber: matchNumbers[matches[matchIndex]] ?? matchIndex + 1,
          homeSourceLabel: sourceLabels[matches[matchIndex]]?.first,
          awaySourceLabel: sourceLabels[matches[matchIndex]]?.second,
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

class _TripleEliminationBracketView extends StatelessWidget {
  const _TripleEliminationBracketView({
    required this.stage,
    required this.matchNumbers,
    required this.sourceLabels,
    required this.sourceMatches,
    required this.qualifyingRank,
    required this.onEditResult,
    required this.canEditResults,
    required this.isEditMode,
    this.onSwapSlot,
  });

  final KnockoutTournamentRunStage stage;
  final Map<GroupMatch, int> matchNumbers;
  final Map<GroupMatch, ({String? first, String? second})> sourceLabels;
  final Map<GroupMatch, ({GroupMatch? first, GroupMatch? second})> sourceMatches;
  final int qualifyingRank;
  final void Function(GroupMatch match) onEditResult;
  final bool canEditResults;
  final bool isEditMode;
  final void Function(int fromSlotIndex, int toSlotIndex)? onSwapSlot;

  @override
  Widget build(BuildContext context) {
    final finalMatches = _matchesWithLabel(stage.rounds, _tripleFinalLabel);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var lossCount = 0; lossCount < 3; lossCount++) ...[
          _BracketBandTitle(
            title: _lossLevelBracketLabel(lossCount),
          ),
          const SizedBox(height: 8),
          _BracketTreeLayout(
            totalRounds: _lossLevelRounds(lossCount).length,
            columnWidth: 260,
            cardHeight: 204,
            firstRoundGap: 12,
            useBalancedColumnLayout: true,
            roundMatches: _lossLevelRounds(lossCount),
            sourceMatches: sourceMatches,
            roundTitles: [
              for (var roundIndex = 0;
                  roundIndex < _lossLevelRounds(lossCount).length;
                  roundIndex++)
                lossCount == 0
                    ? _bracketRoundTitle(
                        roundIndex,
                        _lossLevelRounds(lossCount).length,
                      )
                    : _lossLevelMatchLabel(lossCount, roundIndex + 1),
            ],
            roundCards: [
              for (var roundIndex = 0;
                  roundIndex < _lossLevelRounds(lossCount).length;
                  roundIndex++)
                _matchCards(_lossLevelRounds(lossCount)[roundIndex], roundIndex),
            ],
          ),
          const SizedBox(height: 18),
        ],
        _BracketBandTitle(title: 'Finale'),
        const SizedBox(height: 8),
        _BracketTreeLayout(
          totalRounds: finalMatches.isEmpty ? 0 : 1,
          columnWidth: 260,
          cardHeight: 204,
          firstRoundGap: 12,
          useBalancedColumnLayout: true,
          roundMatches: [finalMatches],
          sourceMatches: sourceMatches,
          roundTitles: const [_tripleFinalLabel],
          roundCards: [
            _matchCards(finalMatches, 0),
          ],
        ),
      ],
    );
  }

  List<List<GroupMatch>> _lossLevelRounds(int lossCount) {
    final rounds = <List<GroupMatch>>[];
    var roundNumber = 1;
    while (true) {
      final matches = _matchesWithLabel(
        stage.rounds,
        _lossLevelMatchLabel(lossCount, roundNumber),
      );
      if (matches.isEmpty) {
        break;
      }
      rounds.add(matches);
      roundNumber++;
    }
    return rounds;
  }

  List<Widget> _matchCards(List<GroupMatch> matches, int roundIndex) {
    return [
      for (var matchIndex = 0; matchIndex < matches.length; matchIndex++)
        _KnockoutBracketMatchCard(
          match: matches[matchIndex],
          matchNumber: matchNumbers[matches[matchIndex]] ?? matchIndex + 1,
          homeSourceLabel: sourceLabels[matches[matchIndex]]?.first,
          awaySourceLabel: sourceLabels[matches[matchIndex]]?.second,
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
  final remainingRounds = totalRounds - roundIndex;
  if (remainingRounds == 4) {
    return 'Achtelfinale';
  }
  if (remainingRounds == 3) {
    return 'Viertelfinale';
  }
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
    this.roundMatches,
    this.sourceMatches,
    this.useBalancedColumnLayout = false,
  });

  static const double _headerHeight = 34;
  static const double _headerGap = 10;
  static const double _connectorWidth = 34;

  final int totalRounds;
  final List<String> roundTitles;
  final List<List<Widget>> roundCards;
  final List<List<GroupMatch>>? roundMatches;
  final Map<GroupMatch, ({GroupMatch? first, GroupMatch? second})>? sourceMatches;
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

    return _BracketPanViewport(
      width: width,
      height: height,
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
                  connections: _connections(),
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

  List<_BracketConnection> _connections() {
    if (roundMatches == null || sourceMatches == null) {
      return _fallbackConnections();
    }

    final positions = <GroupMatch, ({int roundIndex, int matchIndex})>{};
    final matches = roundMatches!;
    final sourcesByMatch = sourceMatches!;
    for (var roundIndex = 0; roundIndex < matches.length; roundIndex++) {
      for (var matchIndex = 0;
          matchIndex < matches[roundIndex].length;
          matchIndex++) {
        positions[matches[roundIndex][matchIndex]] = (
          roundIndex: roundIndex,
          matchIndex: matchIndex,
        );
      }
    }

    final connections = <_BracketConnection>[];
    for (var roundIndex = 0; roundIndex < matches.length; roundIndex++) {
      for (var matchIndex = 0;
          matchIndex < matches[roundIndex].length;
          matchIndex++) {
        final target = matches[roundIndex][matchIndex];
        final sources = sourcesByMatch[target];
        if (sources == null) {
          continue;
        }
        for (final source in [sources.first, sources.second]) {
          final sourcePosition = source == null ? null : positions[source];
          if (sourcePosition == null ||
              sourcePosition.roundIndex >= roundIndex) {
            continue;
          }
          connections.add(
            _BracketConnection(
              fromRoundIndex: sourcePosition.roundIndex,
              fromMatchIndex: sourcePosition.matchIndex,
              toRoundIndex: roundIndex,
              toMatchIndex: matchIndex,
            ),
          );
        }
      }
    }
    return connections;
  }

  List<_BracketConnection> _fallbackConnections() {
    final connections = <_BracketConnection>[];
    for (var roundIndex = 0; roundIndex < roundCards.length - 1; roundIndex++) {
      for (var matchIndex = 0;
          matchIndex < roundCards[roundIndex].length;
          matchIndex++) {
        final nextMatchIndex = matchIndex ~/ 2;
        if (nextMatchIndex >= roundCards[roundIndex + 1].length) {
          continue;
        }
        connections.add(
          _BracketConnection(
            fromRoundIndex: roundIndex,
            fromMatchIndex: matchIndex,
            toRoundIndex: roundIndex + 1,
            toMatchIndex: nextMatchIndex,
          ),
        );
      }
    }
    return connections;
  }
}

class _BracketPanViewport extends StatefulWidget {
  const _BracketPanViewport({
    required this.width,
    required this.height,
    required this.child,
  });

  final double width;
  final double height;
  final Widget child;

  @override
  State<_BracketPanViewport> createState() => _BracketPanViewportState();
}

class _BracketPanViewportState extends State<_BracketPanViewport> {
  final ScrollController _horizontalController = ScrollController();
  final ScrollController _verticalController = ScrollController();
  bool _isRightDragging = false;
  Offset? _lastPointerPosition;

  @override
  void dispose() {
    _horizontalController.dispose();
    _verticalController.dispose();
    super.dispose();
  }

  void _startRightDrag(PointerDownEvent event) {
    if ((event.buttons & kSecondaryMouseButton) == 0) {
      return;
    }
    setState(() {
      _isRightDragging = true;
      _lastPointerPosition = event.position;
    });
  }

  void _updateRightDrag(PointerMoveEvent event) {
    if (!_isRightDragging ||
        (event.buttons & kSecondaryMouseButton) == 0 ||
        _lastPointerPosition == null) {
      return;
    }

    final delta = event.position - _lastPointerPosition!;
    _lastPointerPosition = event.position;
    _moveController(_horizontalController, -delta.dx);
    _moveController(_verticalController, -delta.dy);
  }

  void _endRightDrag(PointerEvent event) {
    if (!_isRightDragging) {
      return;
    }
    setState(() {
      _isRightDragging = false;
      _lastPointerPosition = null;
    });
  }

  void _moveController(ScrollController controller, double delta) {
    if (!controller.hasClients) {
      return;
    }
    final position = controller.position;
    final nextOffset = (position.pixels + delta).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    controller.jumpTo(nextOffset);
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    final viewportHeight = min(widget.height, max(360.0, screenHeight * 0.72));

    return SizedBox(
      height: viewportHeight,
      child: Listener(
        onPointerDown: _startRightDrag,
        onPointerMove: _updateRightDrag,
        onPointerUp: _endRightDrag,
        onPointerCancel: _endRightDrag,
        child: MouseRegion(
          cursor: _isRightDragging
              ? SystemMouseCursors.grabbing
              : SystemMouseCursors.basic,
          child: Scrollbar(
            controller: _verticalController,
            child: SingleChildScrollView(
              controller: _verticalController,
              child: Scrollbar(
                controller: _horizontalController,
                notificationPredicate: (notification) =>
                    notification.metrics.axis == Axis.horizontal,
                child: SingleChildScrollView(
                  controller: _horizontalController,
                  scrollDirection: Axis.horizontal,
                  child: widget.child,
                ),
              ),
            ),
          ),
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
    required this.connections,
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
  final List<_BracketConnection> connections;
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

    for (final connection in connections) {
      if (connection.fromRoundIndex >= roundCards.length ||
          connection.toRoundIndex >= roundCards.length ||
          connection.fromMatchIndex >=
              roundCards[connection.fromRoundIndex].length ||
          connection.toMatchIndex >= roundCards[connection.toRoundIndex].length) {
        continue;
      }

      final startX =
          connection.fromRoundIndex * (columnWidth + connectorWidth) + columnWidth;
      final endX = connection.toRoundIndex * (columnWidth + connectorWidth);
      final midX = startX + (endX - startX) / 2;
      final startY =
          _centerY(connection.fromRoundIndex, connection.fromMatchIndex);
      final endY = _centerY(connection.toRoundIndex, connection.toMatchIndex);

      final path = Path()
        ..moveTo(startX, startY)
        ..lineTo(midX, startY)
        ..lineTo(midX, endY)
        ..lineTo(endX, endY);
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _BracketConnectorPainter oldDelegate) {
    return oldDelegate.totalRounds != totalRounds ||
        oldDelegate.roundCards != roundCards ||
        oldDelegate.connections != connections ||
        oldDelegate.columnWidth != columnWidth ||
        oldDelegate.connectorWidth != connectorWidth ||
        oldDelegate.cardHeight != cardHeight ||
        oldDelegate.firstRoundGap != firstRoundGap ||
        oldDelegate.useBalancedColumnLayout != useBalancedColumnLayout ||
        oldDelegate.color != color;
  }
}

class _BracketConnection {
  const _BracketConnection({
    required this.fromRoundIndex,
    required this.fromMatchIndex,
    required this.toRoundIndex,
    required this.toMatchIndex,
  });

  final int fromRoundIndex;
  final int fromMatchIndex;
  final int toRoundIndex;
  final int toMatchIndex;
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
    this.homeSourceLabel,
    this.awaySourceLabel,
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
  final String? homeSourceLabel;
  final String? awaySourceLabel;
  final void Function(int fromSlotIndex, int toSlotIndex)? onSwapSlot;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final winner = match.winner;
    final qualificationLabel = _bracketQualificationLabel();
    final homeLabel = _emptySlotLabel(
      sourceLabel: homeSourceLabel,
      isEmpty: match.homePlayer == null,
      opponent: match.awayPlayer,
      allowsBye: match.allowsBye,
    );
    final awayLabel = _emptySlotLabel(
      sourceLabel: awaySourceLabel,
      isEmpty: match.awayPlayer == null,
      opponent: match.homePlayer,
      allowsBye: match.allowsBye,
    );

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
            score: match.homePlayer == null ? null : match.homeLegs,
            isWinner: match.hasResult &&
                _isRealBracketPlayer(match.homePlayer) &&
                winner == match.homePlayer,
            label: homeLabel,
            slotIndex: matchIndex * 2,
            isEditable: isEditMode && roundIndex == 0,
            onSwapSlot: onSwapSlot,
          ),
          const SizedBox(height: 6),
          _BracketPlayerSlot(
            player: match.awayPlayer,
            score: match.awayPlayer == null ? null : match.awayLegs,
            isWinner: match.hasResult &&
                _isRealBracketPlayer(match.awayPlayer) &&
                winner == match.awayPlayer,
            label: awayLabel,
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

String? _emptySlotLabel({
  required String? sourceLabel,
  required bool isEmpty,
  required TournamentPlayer? opponent,
  required bool allowsBye,
}) {
  if (!isEmpty) {
    return null;
  }
  if (_isRealBracketPlayer(opponent) &&
      (sourceLabel == null || sourceLabel == opponent!.name)) {
    return 'Freilos';
  }
  return sourceLabel ?? (allowsBye ? 'Freilos' : null);
}

bool _isRealBracketPlayer(TournamentPlayer? player) {
  if (player == null) {
    return false;
  }

  final name = player.name.trim();
  return name.isNotEmpty &&
      name != 'Freilos' &&
      name != 'offen' &&
      name != _autoAdvanceLabel &&
      !name.startsWith('Gewinner Spiel ') &&
      !name.startsWith('Verlierer Spiel ');
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
  });

  final GroupMatch match;
  final void Function(GroupMatch match) onEditResult;
  final bool canEditResult;
  final String? originLabel;
  final String? leadingLabel;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final canEdit = canEditResult && match.hasPlayers;
    final roundLabel = leadingLabel ?? 'Runde ${match.round}';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 520) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      roundLabel,
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                    if (originLabel != null)
                      _MatchOriginChip(label: originLabel!),
                  ],
                ),
                const SizedBox(height: 8),
                Text(match.homePlayer?.name ?? 'offen'),
                const SizedBox(height: 4),
                Text(match.awayPlayer?.name ?? 'offen'),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _ScoreBadge(
                      match: match,
                      onTap: canEdit ? () => onEditResult(match) : null,
                    ),
                    const Spacer(),
                    IconButton.filledTonal(
                      onPressed: canEdit ? () => onEditResult(match) : null,
                      icon: const Icon(Icons.edit_outlined),
                      tooltip: 'Ergebnis',
                    ),
                  ],
                ),
              ],
            );
          }

          return Row(
            children: [
              SizedBox(
                width: leadingLabel == null ? 74 : 148,
                child: Text(
                  roundLabel,
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ),
              const SizedBox(width: 8),
              if (originLabel != null) ...[
                _MatchOriginChip(label: originLabel!),
                const SizedBox(width: 8),
              ],
              Expanded(child: Text(match.homePlayer?.name ?? 'offen')),
              _ScoreBadge(
                match: match,
                onTap: canEdit ? () => onEditResult(match) : null,
              ),
              Expanded(
                child: Text(
                  match.awayPlayer?.name ?? 'offen',
                  textAlign: TextAlign.right,
                ),
              ),
              const SizedBox(width: 12),
              IconButton.filledTonal(
                onPressed: canEdit ? () => onEditResult(match) : null,
                icon: const Icon(Icons.edit_outlined),
                tooltip: 'Ergebnis',
              ),
            ],
          );
        },
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

