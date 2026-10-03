import 'package:flutter/material.dart';
import '../../domain/tournament_format_planner.dart';
import 'planning_suggestion_card.dart';

/// Reveals the next ranked results without repeating the search or losing the
/// already visible proposals. A new search resets the visible page.
class PlanningSuggestionList extends StatefulWidget {
  const PlanningSuggestionList({
    super.key,
    required this.suggestions,
    required this.pageSize,
    required this.onSelected,
  });
  final List<TournamentFormatSuggestion> suggestions;
  final int pageSize;
  final ValueChanged<TournamentFormatSuggestion> onSelected;
  @override
  State<PlanningSuggestionList> createState() => _PlanningSuggestionListState();
}

class _PlanningSuggestionListState extends State<PlanningSuggestionList> {
  late int visible = widget.pageSize;
  @override
  void didUpdateWidget(PlanningSuggestionList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.suggestions, widget.suggestions) ||
        oldWidget.pageSize != widget.pageSize) {
      visible = widget.pageSize;
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final suggestion in widget.suggestions.take(visible))
        PlanningSuggestionCard(
          suggestion: suggestion,
          onSelected: () => widget.onSelected(suggestion),
        ),
      if (visible < widget.suggestions.length)
        OutlinedButton.icon(
          key: const ValueKey('planner-more-suggestions'),
          onPressed: () => setState(() => visible += widget.pageSize),
          icon: const Icon(Icons.add),
          label: const Text('Weitere Vorschläge'),
        )
      else if (widget.suggestions.isNotEmpty)
        const Padding(
          padding: EdgeInsets.all(12),
          child: Text(
            'Alle gefundenen Vorschläge angezeigt. Für andere Ergebnisse die Suchvorgaben ändern.',
          ),
        ),
    ],
  );
}
