import 'package:flutter/material.dart';

import '../../../domain/tournament_models.dart';
import 'best_of_comparison_table.dart';
import 'group_run_section.dart';
import 'mini_knockout_group_run_section.dart';
import 'stage_surface.dart';

typedef MiniKnockoutBracketBuilder =
    Widget Function(
      TournamentGroup group,
      int qualifyingRank,
      void Function(GroupMatch match) onEditResult,
      bool canEditResults,
    );

class GroupStageRunSection extends StatelessWidget {
  const GroupStageRunSection({
    super.key,
    required this.stage,
    required this.standingsFor,
    required this.onEditResult,
    required this.canEditResults,
    required this.miniKnockoutBracketBuilder,
  });

  final GroupTournamentRunStage stage;
  final List<PlayerStanding> Function(
    TournamentGroup group,
    List<String> tieBreakers,
  )
  standingsFor;
  final void Function(GroupMatch match) onEditResult;
  final bool canEditResults;
  final MiniKnockoutBracketBuilder miniKnockoutBracketBuilder;

  @override
  Widget build(BuildContext context) {
    final standingsByGroup = {
      for (final group in stage.groups)
        if (group.playType == 'round_robin')
          group: standingsFor(group, stage.tieBreakers),
    };

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
          const SizedBox(height: 16),
          for (var index = 0; index < stage.groups.length; index++)
            if (_isEliminationGroupPlayType(stage.groups[index].playType))
              MiniKnockoutGroupRunSection(
                group: stage.groups[index],
                bracket: miniKnockoutBracketBuilder(
                  stage.groups[index],
                  _requiredRankForMiniGroup(stage, index),
                  onEditResult,
                  canEditResults,
                ),
              )
            else
              GroupRunSection(
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
            BestOfComparisonTable(
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

bool _isEliminationGroupPlayType(String playType) {
  return playType == 'mini_knockout' ||
      playType == 'double_elimination' ||
      playType == 'triple_elimination';
}
