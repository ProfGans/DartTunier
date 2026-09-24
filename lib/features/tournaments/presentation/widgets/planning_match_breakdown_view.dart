import 'package:flutter/material.dart';
import '../../domain/planning_match_breakdown.dart';

class PlanningMatchBreakdownView extends StatelessWidget {
  const PlanningMatchBreakdownView({super.key, required this.breakdown});
  final PlanningMatchBreakdown breakdown;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'So entstehen die ${breakdown.total} Spiele',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const Text('Jeder gegen jeden: n × (n − 1) ÷ 2'),
        for (var index = 0; index < breakdown.groupSizes.length; index++)
          Text(
            'Gruppe ${index + 1}: ${breakdown.groupSizes[index]} Spieler → '
            '${breakdown.groupSizes[index]} × ${breakdown.groupSizes[index] - 1} ÷ 2 = ${breakdown.groupMatches[index]} Spiele',
          ),
        if (breakdown.knockoutParticipants > 1) ...[
          Text(
            'K.-o.: ${breakdown.knockoutParticipants} Qualifikanten (bis zu ${breakdown.qualifiersPerGroup} je Gruppe) → '
            '${breakdown.knockoutParticipants} − 1 = ${breakdown.knockoutMatches} Spiele',
          ),
          if (breakdown.byes > 0)
            Text(
              '${breakdown.byes} Freilose zählen nicht als gespielte Matches.',
            ),
        ],
        Text(
          'Gesamt: ${breakdown.groupTotal} Gruppenspiele + ${breakdown.knockoutMatches} K.-o.-Spiele = ${breakdown.total} Spiele',
        ),
        const Text(
          'Spiele sind Matches; die Legs innerhalb eines Matches werden hier nicht einzeln gezählt.',
        ),
      ],
    ),
  );
}
