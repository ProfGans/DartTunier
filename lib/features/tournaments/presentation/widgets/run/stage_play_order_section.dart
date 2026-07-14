import 'package:flutter/material.dart';

import '../../../domain/tournament_models.dart';
import 'result_entry.dart';
import 'stage_surface.dart';

class StagePlayOrderSection extends StatelessWidget {
  const StagePlayOrderSection({
    super.key,
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
              _RoundHeader(title: _roundTitle(rounds[round]!)),
              for (final match in rounds[round]!)
                MatchResultTile(
                  match: match,
                  onEditResult: onEditResult,
                  canEditResult: canEditResults,
                  originLabel: groupLabels[match],
                  leadingLabel: _leadingLabel(match),
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

  String _roundTitle(List<GroupMatch> roundMatches) {
    if (roundMatches.every((match) => _isPlacementMatchLabel(match.label))) {
      return 'Platzierung';
    }
    final firstMatch = roundMatches.isEmpty ? null : roundMatches.first;
    if (firstMatch != null && firstMatch.isDecider) {
      return 'Decider';
    }
    return 'Runde ${firstMatch?.round ?? 0}';
  }

  String? _leadingLabel(GroupMatch match) {
    if (match.isDecider || _isPlacementMatchLabel(match.label)) {
      return match.label;
    }
    return null;
  }

  bool _isPlacementMatchLabel(String? label) {
    return label == 'Spiel um Platz 3' ||
        label == 'Spiel um Platz 5' ||
        label == 'Spiel um Platz 7' ||
        (label?.startsWith('Platz 5 Halbfinale') ?? false);
  }
}

class _RoundHeader extends StatelessWidget {
  const _RoundHeader({required this.title});

  final String title;

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
            title,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
