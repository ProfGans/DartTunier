import 'package:flutter/material.dart';

import '../../tournaments/data/app_database.dart';

class PlayersPage extends StatefulWidget {
  const PlayersPage({super.key, LocalAppDatabase? database})
      : _database = database;

  final LocalAppDatabase? _database;

  @override
  State<PlayersPage> createState() => _PlayersPageState();
}

class _PlayersPageState extends State<PlayersPage> {
  late final LocalAppDatabase _database;
  late Future<List<PlayerProfile>> _playersFuture;

  @override
  void initState() {
    super.initState();
    _database = widget._database ?? LocalAppDatabase();
    _playersFuture = _database.loadPlayerProfiles();
  }

  void _reloadPlayers() {
    setState(() {
      _playersFuture = _database.loadPlayerProfiles();
    });
  }

  Future<void> _openPlayerDialog([PlayerProfile? player]) async {
    final result = await showDialog<_PlayerFormResult>(
      context: context,
      builder: (context) => _PlayerDialog(player: player),
    );
    if (result == null) {
      return;
    }

    if (player == null) {
      await _database.createPlayerProfile(
        displayName: result.displayName,
        country: result.country,
        city: result.city,
        dartsSetupJson: result.dartsSetup,
      );
    } else {
      await _database.updatePlayerProfile(
        player.copyWith(
          displayName: result.displayName,
          country: result.country,
          city: result.city,
          dartsSetupJson: result.dartsSetup,
        ),
      );
    }

    if (!mounted) {
      return;
    }
    _reloadPlayers();
  }

  Future<void> _deactivatePlayer(PlayerProfile player) async {
    await _database.deactivatePlayerProfile(player.id);
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${player.displayName} deaktiviert.')),
    );
    _reloadPlayers();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Spieler'),
        backgroundColor: colorScheme.primaryContainer,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openPlayerDialog(),
        icon: const Icon(Icons.person_add_alt_1_outlined),
        label: const Text('Spieler'),
      ),
      body: SafeArea(
        child: FutureBuilder<List<PlayerProfile>>(
          future: _playersFuture,
          builder: (context, snapshot) {
            final players = snapshot.data ?? const <PlayerProfile>[];
            return ListView(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 96),
              children: [
                Icon(Icons.groups_outlined, size: 64, color: colorScheme.primary),
                const SizedBox(height: 16),
                Text(
                  'Spieler verwalten',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Spielerprofile anlegen und fuer Turniere vorbereiten.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 24),
                if (snapshot.connectionState == ConnectionState.waiting)
                  const Center(child: CircularProgressIndicator())
                else if (players.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('Noch keine Spieler angelegt.'),
                    ),
                  )
                else
                  for (final player in players)
                    Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          child: Text(_initialsFor(player.displayName)),
                        ),
                        title: Text(player.displayName),
                        subtitle: Text(_subtitleFor(player)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              onPressed: () => _openPlayerDialog(player),
                              icon: const Icon(Icons.edit_outlined),
                              tooltip: 'Spieler bearbeiten',
                            ),
                            IconButton(
                              onPressed: () => _deactivatePlayer(player),
                              icon: const Icon(Icons.person_remove_outlined),
                              tooltip: 'Spieler deaktivieren',
                            ),
                          ],
                        ),
                        onTap: () => _openPlayerDialog(player),
                      ),
                    ),
              ],
            );
          },
        ),
      ),
    );
  }

  String _initialsFor(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) {
      return '?';
    }
    return parts.take(2).map((part) => part[0].toUpperCase()).join();
  }

  String _subtitleFor(PlayerProfile player) {
    final location = [
      if (player.city.isNotEmpty) player.city,
      if (player.country.isNotEmpty) player.country,
    ].join(', ');
    if (location.isEmpty && player.dartsSetupJson.isEmpty) {
      return 'Kein Standort hinterlegt';
    }
    if (player.dartsSetupJson.isEmpty) {
      return location;
    }
    if (location.isEmpty) {
      return player.dartsSetupJson;
    }
    return '$location - ${player.dartsSetupJson}';
  }
}

class _PlayerDialog extends StatefulWidget {
  const _PlayerDialog({this.player});

  final PlayerProfile? player;

  @override
  State<_PlayerDialog> createState() => _PlayerDialogState();
}

class _PlayerDialogState extends State<_PlayerDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _countryController;
  late final TextEditingController _cityController;
  late final TextEditingController _dartsSetupController;

  @override
  void initState() {
    super.initState();
    final player = widget.player;
    _nameController = TextEditingController(text: player?.displayName ?? '');
    _countryController = TextEditingController(text: player?.country ?? '');
    _cityController = TextEditingController(text: player?.city ?? '');
    _dartsSetupController = TextEditingController(
      text: player?.dartsSetupJson ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _countryController.dispose();
    _cityController.dispose();
    _dartsSetupController.dispose();
    super.dispose();
  }

  void _submit() {
    final displayName = _nameController.text.trim();
    if (displayName.isEmpty) {
      return;
    }

    Navigator.of(context).pop(
      _PlayerFormResult(
        displayName: displayName,
        country: _countryController.text.trim(),
        city: _cityController.text.trim(),
        dartsSetup: _dartsSetupController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.player != null;

    return AlertDialog(
      title: Text(isEditing ? 'Spieler bearbeiten' : 'Spieler anlegen'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Name',
                prefixIcon: Icon(Icons.person_outline),
              ),
              textInputAction: TextInputAction.next,
              autofocus: true,
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _countryController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Land',
                prefixIcon: Icon(Icons.flag_outlined),
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _cityController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Stadt',
                prefixIcon: Icon(Icons.location_city_outlined),
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _dartsSetupController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Dart-Setup',
                prefixIcon: Icon(Icons.sports_bar_outlined),
              ),
              onSubmitted: (_) => _submit(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Speichern'),
        ),
      ],
    );
  }
}

class _PlayerFormResult {
  const _PlayerFormResult({
    required this.displayName,
    required this.country,
    required this.city,
    required this.dartsSetup,
  });

  final String displayName;
  final String country;
  final String city;
  final String dartsSetup;
}
