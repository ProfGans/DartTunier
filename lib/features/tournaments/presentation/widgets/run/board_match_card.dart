import 'package:flutter/material.dart';

/// Board identity and pairing stay readable; actions have their own touch row.
class BoardMatchCard extends StatelessWidget {
  const BoardMatchCard({
    super.key,
    required this.home,
    required this.away,
    required this.origin,
    required this.status,
    this.action,
    this.running = false,
    this.scorerSummary,
  });
  final String home, away, origin, status;
  final String? scorerSummary;
  final Widget? action;
  final bool running;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: running ? scheme.primaryContainer : scheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  running ? Icons.play_circle_outline : Icons.sports_score,
                  size: 20,
                  color: scheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    status,
                    style: Theme.of(
                      context,
                    ).textTheme.labelLarge?.copyWith(color: scheme.primary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              home,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(away, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            Text(origin, style: Theme.of(context).textTheme.bodySmall),
            if (scorerSummary != null) Text(scorerSummary!),
            if (action != null)
              Align(alignment: Alignment.centerRight, child: action!),
          ],
        ),
      ),
    );
  }
}
