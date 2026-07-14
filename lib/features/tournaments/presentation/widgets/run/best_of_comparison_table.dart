import 'package:flutter/material.dart';

import '../../../domain/tournament_models.dart';

class BestOfComparisonTable extends StatelessWidget {
  const BestOfComparisonTable({
    super.key,
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
