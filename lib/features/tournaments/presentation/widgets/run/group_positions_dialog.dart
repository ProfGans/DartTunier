import 'package:flutter/material.dart';
import '../../../domain/tournament_models.dart';

class GroupPositionsDialog extends StatefulWidget {
  const GroupPositionsDialog({super.key, required this.stage});
  final GroupTournamentRunStage stage;

  @override
  State<GroupPositionsDialog> createState() => _GroupPositionsDialogState();
}

class _GroupPositionsDialogState extends State<GroupPositionsDialog> {
  TournamentPlayer? _selected;

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Gruppenpositionen bearbeiten'),
    content: SizedBox(
      width: 480,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Wähle zwei Spieler, deren Positionen getauscht werden sollen. '
              'Die Gruppengrößen bleiben erhalten.',
            ),
            for (final group in widget.stage.groups) ...[
              const SizedBox(height: 16),
              Text(group.name, style: Theme.of(context).textTheme.titleMedium),
              for (final player in group.players)
                ListTile(
                  title: Text(player.name),
                  selected: _selected == player,
                  leading: Icon(
                    _selected == player
                        ? Icons.check_circle
                        : Icons.person_outline,
                  ),
                  onTap: () {
                    if (_selected == null) {
                      setState(() => _selected = player);
                    } else if (_selected == player) {
                      setState(() => _selected = null);
                    } else {
                      Navigator.pop(context, [_selected!, player]);
                    }
                  },
                ),
            ],
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Abbrechen'),
      ),
    ],
  );
}
