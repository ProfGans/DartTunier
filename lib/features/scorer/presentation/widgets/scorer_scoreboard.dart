import 'package:flutter/material.dart';
import 'scorer_play_sizing.dart';

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
      final sizing = ScorerPlaySizing.of(context);
      final compact = sizing?.compact ?? false;
      final spacious = (sizing?.scoreHeight ?? 0) > 0;
      final scale = MediaQuery.textScalerOf(context).scale(16) / 16;
      final columns = constraints.maxWidth >= (compact ? 280 : 320) * scale
          ? 2
          : 1;
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
                constraints: BoxConstraints(
                  minHeight: sizing?.scoreHeight ?? 0,
                ),
                padding: EdgeInsets.all(
                  spacious
                      ? 24
                      : compact
                      ? 8
                      : 14,
                ),
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
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!compact)
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
                      SizedBox(height: compact ? 0 : 8),
                      Text(
                        player.name,
                        semanticsLabel: compact && player.active
                            ? '${player.name}, am Wurf'
                            : player.name,
                        style: TextStyle(
                          fontSize: spacious
                              ? 26
                              : compact
                              ? 16
                              : 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: compact ? 2 : 6),
                      Text(
                        '${player.score}',
                        style: TextStyle(
                          fontSize:
                              ((width -
                                          (spacious
                                              ? 48
                                              : compact
                                              ? 20
                                              : 28)) /
                                      ((compact ? 3.2 : 2.3) * scale))
                                  .clamp(
                                    compact ? 36.0 : 48.0,
                                    spacious
                                        ? 200.0
                                        : compact
                                        ? 64.0
                                        : 120.0,
                                  ),
                          height: 1.15,
                          fontWeight: FontWeight.w800,
                          color: player.active
                              ? const Color(0xFF70E0BA)
                              : scheme.onSurface,
                        ),
                      ),
                      SizedBox(height: compact ? 2 : 8),
                      Text(
                        '${player.legs} Legs · ${player.sets} Sets',
                        style: TextStyle(fontSize: compact ? 12 : 16),
                      ),
                      if (!compact)
                        Text(
                          '3DA: ${player.average?.toStringAsFixed(2) ?? '—'}',
                          style: TextStyle(fontSize: compact ? 12 : 16),
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
