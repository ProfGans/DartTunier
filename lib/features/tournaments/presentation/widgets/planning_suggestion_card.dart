import 'package:flutter/material.dart';
import '../../domain/tournament_format_planner.dart';
import 'planning_match_breakdown_view.dart';

class PlanningSuggestionCard extends StatelessWidget {
  const PlanningSuggestionCard({
    super.key,
    required this.suggestion,
    required this.onSelected,
  });
  final TournamentFormatSuggestion suggestion;
  final VoidCallback onSelected;
  @override
  Widget build(BuildContext context) => Card(
    child: InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onSelected,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    suggestion.title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 6),
                  for (final stage in suggestion.stages)
                    Text('${stage.label}: ${stage.format.label}'),
                  Text(
                    '${suggestion.totalMatches} Spiele gesamt · mind. ${suggestion.minimumMatchesPerPlayer} je Spieler',
                  ),
                  Text(
                    'ca. ${suggestion.estimatedMinutes ~/ 60} h ${suggestion.estimatedMinutes % 60} min · ${suggestion.effectiveBoards} Boards nutzbar',
                  ),
                  PlanningMatchBreakdownView(
                    breakdown: suggestion.matchBreakdown,
                  ),
                  if (suggestion.duration case final duration?) ...[
                    const SizedBox(height: 12),

                    Text(
                      'Gruppen: ${duration.groupSlots} Zeitblöcke × ${duration.matchMinutes.toStringAsFixed(2)} Min. = ${duration.groupMinutes} Min.',
                    ),
                    Text(
                      'K.-o.: ${duration.knockoutSlots} Zeitblöcke × ${duration.knockoutMatchMinutes.toStringAsFixed(2)} Min. = ${duration.knockoutMinutes} Min.',
                    ),
                    Text(
                      'Gesamt: ${duration.groupMinutes} + ${duration.knockoutMinutes} = ${duration.totalMinutes} Minuten',
                    ),
                    const Text(
                      'Die Gruppenzeit wird mit derselben Board- und Pausenplanung wie Order of Play aus den konkreten Paarungen berechnet. K.-o.-Runden werden bis zum Vorliegen ihrer Ergebnisse rundenweise geschätzt. Unterschiedliche Matchdauern, vorgezogene Spiele und zusätzliche Pausen können die tatsächliche Dauer verändern.',
                    ),
                  ],
                  if (suggestion.isClosestAlternative)
                    const Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: Text(
                        'Nächstbeste Lösung außerhalb der gewünschten Vorgaben',
                      ),
                    ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    ),
  );
}
