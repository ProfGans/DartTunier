import 'package:flutter/material.dart';
import '../../domain/best_performance.dart';

/// Summarizes best performances with collapsible groups for shortlegs and high finishes,
/// avoiding redundant listings for 180s and 170s.
class StructuredBestPerformancesView extends StatelessWidget {
  const StructuredBestPerformancesView({
    super.key,
    required this.bestPerformances,
  });

  final List<BestPerformance> bestPerformances;

  @override
  Widget build(BuildContext context) {
    if (bestPerformances.isEmpty) {
      return const SizedBox.shrink();
    }

    final shortLegs = bestPerformances
        .where((item) => item.type == BestPerformanceType.shortLeg)
        .toList();
    final highFinishes = bestPerformances
        .where((item) => item.type == BestPerformanceType.highFinish)
        .toList();

    // Group shortlegs by dart count (ascending 9 to 18)
    final shortLegsByDarts = <int, int>{};
    for (final item in shortLegs) {
      final darts = item.value ?? 18;
      shortLegsByDarts[darts] = (shortLegsByDarts[darts] ?? 0) + 1;
    }
    final sortedDarts = shortLegsByDarts.keys.toList()..sort();

    // Group high finishes by finish score (descending 170 to 100)
    final highFinishesByScore = <int, int>{};
    for (final item in highFinishes) {
      final score = item.value ?? 100;
      highFinishesByScore[score] = (highFinishesByScore[score] ?? 0) + 1;
    }
    final sortedScores = highFinishesByScore.keys.toList()..sort((a, b) => b.compareTo(a));

    if (shortLegs.isEmpty && highFinishes.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (shortLegs.isNotEmpty)
          Card(
            margin: const EdgeInsets.symmetric(vertical: 4),
            child: ExpansionTile(
              leading: const Icon(Icons.flash_on_outlined, color: Colors.amber),
              title: Text('Shortlegs (${shortLegs.length})'),
              subtitle: const Text('Hier tippen für Aufschlüsselung nach Darts (9–18)'),
              childrenPadding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              children: [
                for (final darts in sortedDarts)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('$darts Darts', style: const TextStyle(fontWeight: FontWeight.w600)),
                        Text(
                          '${shortLegsByDarts[darts]}×',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        if (highFinishes.isNotEmpty)
          Card(
            margin: const EdgeInsets.symmetric(vertical: 4),
            child: ExpansionTile(
              leading: const Icon(Icons.stars_outlined, color: Colors.orange),
              title: Text('High Finishes (${highFinishes.length})'),
              subtitle: const Text('Hier tippen für Aufschlüsselung nach Checkouts'),
              childrenPadding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              children: [
                for (final score in sortedScores)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('$score Checkout', style: const TextStyle(fontWeight: FontWeight.w600)),
                        Text(
                          '${highFinishesByScore[score]}×',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
