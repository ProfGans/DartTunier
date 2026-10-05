part of '../../../tournament_workspace.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<SportDestination> get _destinations => [
    SportDestination(
      'Übersicht',
      Icons.dashboard_outlined,
      () => Navigator.of(context).popUntil((route) => route.isFirst),
    ),
    SportDestination(
      'Turniere',
      Icons.emoji_events_outlined,
      () => _open(const TournamentHomePage(), 1),
    ),
    SportDestination('Scorer', Icons.sports_score, _openScorer),
    SportDestination(
      'Spieler',
      Icons.groups_outlined,
      () => _open(const PlayersPage(), 3),
    ),
    SportDestination('Community', Icons.hub_outlined, _openCommunity),
    SportDestination(
      'Geräte',
      Icons.devices_outlined,
      () => _open(const DevicesPage(), 5),
    ),
    SportDestination(
      'Einstellungen',
      Icons.settings_outlined,
      () => _open(const SettingsPage(), 6),
    ),
  ];

  Future<void> _open(Widget page, int selected) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SportAppShell(
          selected: selected,
          destinations: _destinations,
          child: page,
        ),
      ),
    );
  }

  Future<void> _openScorer() async {
    try {
      final account = await loadCurrentAccount();
      if (!mounted) return;
      await _open(ScorerPage(account: account), 2);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Account konnte nicht geladen werden. Bitte erneut versuchen.',
            ),
          ),
        );
      }
    }
  }

  void _openCommunity() => _open(
    CommunityPage(
      createTournamentBuilder: (id, name, {preset, title}) =>
          TournamentCreationPage(
            communityId: id,
            communityName: name,
            preset: preset,
            presetTitle: title,
          ),
      runTournamentBuilder: (tournament) =>
          TournamentRunPage(tournament: tournament),
    ),
    4,
  );

  void _openTournamentArea() => _open(const TournamentHomePage(), 1);
  void _openPlayersArea() => _open(const PlayersPage(), 3);
  void _openSettings() => _open(const SettingsPage(), 6);
  void _openCommunityArea() => _openCommunity();
  Widget _shell(Widget page, int selected) => SportAppShell(
    destinations: _destinations,
    selected: selected,
    child: page,
  );
  void _createTournament() => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => _shell(const TournamentCreationPage(), 1),
    ),
  );

  @override
  Widget build(BuildContext context) => _shell(
    Scaffold(
      appBar: AppBar(
        title: const Text('Dart Turnierverwaltung'),
        actions: [
          IconButton(
            onPressed: _openSettings,
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Einstellungen',
          ),
        ],
      ),
      body: AdaptiveContentList(
        children: [
          SportHero(onTournament: _createTournament, onScorer: _openScorer),
          const SizedBox(height: 28),
          SportMenuGroup(
            title: 'Spielzentrale',
            actions: [
              SportMenuAction(
                label: 'Turniere',
                icon: Icons.emoji_events_outlined,
                onTap: _openTournamentArea,
              ),
              SportMenuAction(
                label: 'Scorer',
                icon: Icons.sports_score,
                onTap: _openScorer,
              ),
              SportMenuAction(
                label: 'Spieler',
                icon: Icons.groups_outlined,
                onTap: _openPlayersArea,
              ),
              SportMenuAction(
                label: 'Community',
                icon: Icons.hub_outlined,
                onTap: _openCommunityArea,
              ),
            ],
          ),
          Text('Dein Konto', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          const AccountMenuCard(),
          const SizedBox(height: 20),
          Card(
            child: ExpansionTile(
              title: const Text('Werkzeuge & Verwaltung'),
              leading: const Icon(Icons.tune),
              maintainState: true,
              childrenPadding: const EdgeInsets.all(16),
              children: [
                const PushSenderMenu(),
                const PushDeviceMenu(),
                const AutoscoreTesterMenuCard(),
                ListTile(
                  leading: const Icon(Icons.science_outlined),
                  title: const Text('Dev Tools'),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const DevToolsPage(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
    0,
  );
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
      MaterialPageRoute<void>(builder: (_) => _tournamentPageFor(tournament)),
    );
    _reloadTournaments();
  }

  Widget _tournamentPageFor(CreatedTournament tournament) {
    final lastStageIndex = tournament.runStages.length - 1;
    if (lastStageIndex >= 0 &&
        tournament.completedStageIndexes.contains(lastStageIndex)) {
      return TournamentResultsPage(tournament: tournament);
    }
    return TournamentRunPage(tournament: tournament);
  }

  Future<void> _deleteTournament(CreatedTournament tournament) async {
    try {
      await _storage.deleteTournament(tournament.id);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Löschen nicht möglich: $error')),
        );
      }
      return;
    }
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('${tournament.name} geloescht.')));
    _reloadTournaments();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Turniere')),
      body: SafeArea(
        child: FutureBuilder<List<CreatedTournament>>(
          future: _tournamentsFuture,
          builder: (context, snapshot) {
            final tournaments = snapshot.data ?? const <CreatedTournament>[];

            return AdaptiveContentList(
              padding: const EdgeInsets.all(24),
              children: [
                Text(
                  'Meine Turniere',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 6),
                Text(
                  '${tournaments.length} gespeicherte Turniere',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _openCreationPage,
                  icon: const Icon(Icons.add),
                  label: const Text('Turnier erstellen'),
                ),
                const SizedBox(height: 20),
                if (snapshot.connectionState == ConnectionState.waiting)
                  const LinearProgressIndicator(),
                if (snapshot.hasError) ...[
                  const Text('Turniere konnten nicht geladen werden.'),
                  TextButton(
                    onPressed: _reloadTournaments,
                    child: const Text('Erneut versuchen'),
                  ),
                ],
                if (tournaments.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('Noch keine Turniere gespeichert.'),
                    ),
                  )
                else
                  AdaptiveTileLayout(
                    minTileWidth: 360,
                    children: [
                      for (final tournament in tournaments)
                        TournamentSummaryCard(
                          tournament: tournament,
                          onOpen: () => _openTournament(tournament),
                          onDelete: () => _deleteTournament(tournament),
                        ),
                    ],
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
