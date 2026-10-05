import 'package:flutter/material.dart';

class ScorerScoreboardPlayer {
  const ScorerScoreboardPlayer({
    required this.name,
    required this.score,
    required this.legs,
    required this.sets,
    required this.average,
    required this.active,
    required this.bot,
  });
  final String name;
  final int score, legs, sets;
  final double? average;
  final bool active, bot;
}

/// Natural-height score panels keep long names readable at every text scale.
class ScorerScoreboard extends StatelessWidget {
  const ScorerScoreboard({super.key, required this.players});
  final List<ScorerScoreboardPlayer> players;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final scale = MediaQuery.textScalerOf(context).scale(16) / 16;
      final columns = constraints.maxWidth >= 300 * scale ? 2 : 1;
      final width = (constraints.maxWidth - (columns - 1) * 10) / columns;
      final scheme = Theme.of(context).colorScheme;
      return Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (final player in players)
            SizedBox(
              width: width,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: player.active ? scheme.secondary : scheme.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: player.active
                        ? scheme.primary
                        : scheme.outlineVariant,
                    width: player.active ? 2 : 1,
                  ),
                ),
                child: DefaultTextStyle(
                  style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                    color: player.active
                        ? scheme.onSecondary
                        : scheme.onSurface,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Icon(
                            player.bot
                                ? Icons.smart_toy_outlined
                                : Icons.person_outline,
                            size: 18,
                            color: player.active
                                ? const Color(0xFF70E0BA)
                                : scheme.primary,
                          ),
                          Text(
                            player.active ? 'Am Wurf' : 'Spielstand',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        player.name,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${player.score}',
                        style: TextStyle(
                          fontSize: 42,
                          height: 1.15,
                          fontWeight: FontWeight.w800,
                          color: player.active
                              ? const Color(0xFF70E0BA)
                              : scheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${player.legs} Legs · ${player.sets} Sets',
                        style: const TextStyle(fontSize: 12),
                      ),
                      Text(
                        '3DA: ${player.average?.toStringAsFixed(2) ?? '—'}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      );
    },
  );
}
