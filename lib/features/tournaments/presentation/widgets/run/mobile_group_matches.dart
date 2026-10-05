import 'package:flutter/material.dart';
import '../../../domain/tournament_models.dart';
import 'result_entry.dart';

/// The mobile group view puts playable matches ahead of optional detail tables.
class MobileGroupMatches extends StatelessWidget {
  const MobileGroupMatches({
    super.key,
    required this.group,
    required this.table,
    required this.onEditResult,
    required this.canEditResults,
  });
  final TournamentGroup group;
  final Widget table;
  final void Function(GroupMatch) onEditResult;
  final bool canEditResults;

  @override
  Widget build(BuildContext context) {
    final pending = group.matches.where((match) => !match.isResolved).toList();
    final finished = group.matches.where((match) => match.isResolved).toList();
    Widget tile(GroupMatch match) => MatchResultTile(
      match: match,
      onEditResult: onEditResult,
      canEditResult: canEditResults,
      leadingLabel: match.isDecider ? match.label : null,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(group.name, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 4),
        Text('${pending.length} offen · ${finished.length} abgeschlossen'),
        const SizedBox(height: 12),
        if (pending.isNotEmpty) ...[
          Text('Offene Spiele', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          for (final match in pending) tile(match),
        ] else
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text('Alle Spiele dieser Gruppe sind abgeschlossen.'),
          ),
        Card(
          child: ExpansionTile(
            key: PageStorageKey('table-${group.name}'),
            maintainState: true,
            title: const Text('Tabelle & Qualifikation'),
            leading: const Icon(Icons.leaderboard_outlined),
            childrenPadding: const EdgeInsets.all(12),
            children: [
              const Text(
                'Für weitere Spalten die Tabelle seitlich verschieben.',
              ),
              const SizedBox(height: 8),
              table,
            ],
          ),
        ),
        if (finished.isNotEmpty)
          Card(
            child: ExpansionTile(
              key: PageStorageKey('finished-${group.name}'),
              maintainState: true,
              title: Text('Abgeschlossene Spiele (${finished.length})'),
              leading: const Icon(Icons.check_circle_outline),
              childrenPadding: const EdgeInsets.all(12),
              children: [for (final match in finished) tile(match)],
            ),
          ),
      ],
    );
  }
}
