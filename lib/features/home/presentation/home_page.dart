part of '../../../tournament_workspace.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Future<void> _openTournamentArea() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const TournamentHomePage()),
    );
  }

  Future<void> _openPlayersArea() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const PlayersPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dart Turnierverwaltung'),
        backgroundColor: colorScheme.primaryContainer,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Icon(Icons.dashboard_outlined, size: 64, color: colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              'Hauptmenue',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Waehle einen Bereich der Turnierverwaltung.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 24),
            Card(
              child: ListTile(
                leading: const Icon(Icons.emoji_events_outlined),
                title: const Text('Turniere'),
                subtitle: const Text(
                  'Turniere erstellen, fortsetzen und verwalten.',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: _openTournamentArea,
              ),
            ),
            Card(
              child: ListTile(
                leading: const Icon(Icons.groups_outlined),
                title: const Text('Spieler'),
                subtitle: const Text(
                  'Spielerprofile anlegen, bearbeiten und verwalten.',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: _openPlayersArea,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TournamentHomePage extends StatefulWidget {
  const TournamentHomePage({super.key});

  @override
  State<TournamentHomePage> createState() => _TournamentHomePageState();
}

class _TournamentHomePageState extends State<TournamentHomePage> {
  final _storage = TournamentStorage();
  late Future<List<CreatedTournament>> _tournamentsFuture;

  @override
  void initState() {
    super.initState();
    _tournamentsFuture = _storage.loadTournaments();
  }

  void _reloadTournaments() {
    setState(() {
      _tournamentsFuture = _storage.loadTournaments();
    });
  }

  Future<void> _openCreationPage() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const TournamentCreationPage()),
    );
    _reloadTournaments();
  }

  Future<void> _openTournament(CreatedTournament tournament) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TournamentRunPage(tournament: tournament),
      ),
    );
    _reloadTournaments();
  }

  Future<void> _deleteTournament(CreatedTournament tournament) async {
    await _storage.deleteTournament(tournament.id);
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${tournament.name} geloescht.')),
    );
    _reloadTournaments();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Turniere'),
        backgroundColor: colorScheme.primaryContainer,
      ),
      body: SafeArea(
        child: FutureBuilder<List<CreatedTournament>>(
          future: _tournamentsFuture,
          builder: (context, snapshot) {
            final tournaments = snapshot.data ?? const <CreatedTournament>[];

            return ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Icon(Icons.sports_score, size: 64, color: colorScheme.primary),
                const SizedBox(height: 16),
                Text(
                  'Meine Turniere',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Gespeicherte Turniere fortsetzen oder ein neues Turnier anlegen.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _openCreationPage,
                  icon: const Icon(Icons.add_circle_outline),
                  label: const Text('Turnier erstellen'),
                ),
                const SizedBox(height: 32),
                Text(
                  'Gespeicherte Turniere',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                if (tournaments.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('Noch keine Turniere gespeichert.'),
                    ),
                  )
                else
                  for (final tournament in tournaments)
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.emoji_events_outlined),
                        title: Text(tournament.name),
                        subtitle: Text(
                          '${tournament.players.length} Spieler - '
                          '${tournament.stages.length} Etappen',
                        ),
                        trailing: IconButton(
                          onPressed: () => _deleteTournament(tournament),
                          icon: const Icon(Icons.delete_outline),
                          tooltip: 'Turnier loeschen',
                        ),
                        onTap: () => _openTournament(tournament),
                      ),
                    ),
              ],
            );
          },
        ),
      ),
    );
  }
}

