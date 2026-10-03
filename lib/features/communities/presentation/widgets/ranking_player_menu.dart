import 'package:flutter/material.dart';
import '../../domain/community_ranking_action.dart';

/// Put actions above the text on narrow layouts so large names stay readable.
class RankingPlayerTile extends StatelessWidget {
  const RankingPlayerTile({
    super.key,
    required this.title,
    required this.subtitle,
    this.position,
    this.menu,
    this.onTap,
  });
  final String title, subtitle;
  final int? position;
  final Widget? menu;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final scale = MediaQuery.textScalerOf(context).scale(16) / 16;
      if (constraints.maxWidth >= 600 * scale) {
        return ListTile(
          leading: position == null
              ? null
              : CircleAvatar(child: Text('$position')),
          title: Text(title),
          subtitle: Text(subtitle),
          trailing: menu,
          onTap: onTap,
        );
      }
      return InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (position != null || menu != null)
                Row(
                  children: [
                    if (position != null) Text('Platz $position'),
                    const Spacer(),
                    ?menu,
                  ],
                ),
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(subtitle),
            ],
          ),
        ),
      );
    },
  );
}

class RankingPlayerMenu extends StatelessWidget {
  const RankingPlayerMenu({
    super.key,
    required this.onAction,
    this.excluded = false,
  });
  final ValueChanged<RankingPlayerAction>? onAction;
  final bool excluded;
  @override
  Widget build(BuildContext context) => PopupMenuButton<RankingPlayerAction>(
    tooltip: 'Spielerwertung verwalten',
    enabled: onAction != null,
    onSelected: onAction,
    itemBuilder: (_) => [
      PopupMenuItem(
        value: RankingPlayerAction.reset,
        child: Text(
          excluded
              ? 'Mit 1000 Elo wieder aufnehmen'
              : 'Spielerwertung zurücksetzen',
        ),
      ),
      if (!excluded)
        const PopupMenuItem(
          value: RankingPlayerAction.remove,
          child: Text('Aus Rangliste entfernen'),
        ),
    ],
  );
}

Future<bool> confirmRankingPlayerAction(
  BuildContext context,
  String player,
  String ranking,
  RankingPlayerAction action,
) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: Text(
          action == RankingPlayerAction.reset
              ? 'Spielerwertung zurücksetzen?'
              : 'Aus Rangliste entfernen?',
        ),
        content: Text(
          action == RankingPlayerAction.reset
              ? '$player startet in „$ranking“ wieder mit 1000 Elo, null Spielen und einem neuen Elo-Verlauf. Ein entfernter Spieler wird wieder aufgenommen. Dies gilt für Jahres- und Gesamtwertung. Turnierergebnisse bleiben erhalten.'
              : '$player wird aus „$ranking“ entfernt. Weitere Spiele mit diesem Spieler zählen dort für beide Beteiligten nicht zur Wertung. Bereits gewertete Ergebnisse der Gegner bleiben erhalten. Die Community-Mitgliedschaft und andere Ranglisten bleiben bestehen.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              action == RankingPlayerAction.reset
                  ? 'Zurücksetzen'
                  : 'Entfernen',
            ),
          ),
        ],
      ),
    ) ??
    false;
