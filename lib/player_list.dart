part of 'main.dart';

class _PlayerList extends StatelessWidget {
  const _PlayerList({
    required this.players,
    required this.onRenamePlayer,
    required this.onRemovePlayer,
  });

  final List<TournamentPlayer> players;
  final void Function(int index) onRenamePlayer;
  final void Function(int index) onRemovePlayer;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    if (players.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Text('Noch keine Spieler hinzugefuegt.'),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${players.length} Spieler im Turnier',
          style: textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var index = 0; index < players.length; index++)
              InputChip(
                avatar: CircleAvatar(
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                label: Text(players[index].name),
                tooltip: players[index].isGenerated
                    ? 'Erzeugten Spieler umbenennen'
                    : 'Spieler bearbeiten',
                onPressed: () => onRenamePlayer(index),
                onDeleted: () => onRemovePlayer(index),
                deleteIcon: const Icon(Icons.close, size: 18),
              ),
          ],
        ),
      ],
    );
  }
}

