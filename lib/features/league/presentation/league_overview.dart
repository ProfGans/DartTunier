import 'package:flutter/material.dart';
import '../domain/league_match.dart';

class LeagueOverview extends StatelessWidget {
  const LeagueOverview({super.key, required this.league});
  final LeagueMatch league;
  @override
  Widget build(BuildContext context) {
    final played = league.games.where((g) => g.complete).length;
    final homeLegs = league.games.fold<int>(0, (n, g) => n + (g.homeLegs ?? 0));
    final awayLegs = league.games.fold<int>(0, (n, g) => n + (g.awayLegs ?? 0));
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Mannschaftsvergleich',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Text(
              '${league.homeTeam} ${league.homePoints}:${league.awayPoints} ${league.awayTeam}',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            Text('$played von 18 Spielen abgeschlossen · ${league.outcome}'),
            const SizedBox(height: 12),
            LinearProgressIndicator(value: played / 18, minHeight: 8),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: constraints.maxWidth),
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('Mannschaft')),
                      DataColumn(label: Text('Sp')),
                      DataColumn(label: Text('S')),
                      DataColumn(label: Text('N')),
                      DataColumn(label: Text('Legs')),
                      DataColumn(label: Text('Punkte')),
                    ],
                    rows: [
                      for (var side = 0; side < 2; side++)
                        DataRow(
                          cells: [
                            DataCell(
                              Text(
                                side == 0 ? league.homeTeam : league.awayTeam,
                              ),
                            ),
                            DataCell(Text('$played')),
                            DataCell(
                              Text(
                                '${side == 0 ? league.homePoints : league.awayPoints}',
                              ),
                            ),
                            DataCell(
                              Text(
                                '${side == 0 ? league.awayPoints : league.homePoints}',
                              ),
                            ),
                            DataCell(
                              Text(
                                side == 0
                                    ? '$homeLegs:$awayLegs'
                                    : '$awayLegs:$homeLegs',
                              ),
                            ),
                            DataCell(
                              Text(
                                '${side == 0 ? league.homePoints : league.awayPoints}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const Text(
              'Sp = gespielte Matches · S = Siege · N = Niederlagen. Auf kleinen Displays Tabelle seitlich verschieben. Bei 9:9 endet das Ligaspiel unentschieden.',
            ),
          ],
        ),
      ),
    );
  }
}

class LeagueFixtureCard extends StatelessWidget {
  const LeagueFixtureCard({
    super.key,
    required this.league,
    required this.index,
    required this.actions,
    this.boardLabel,
    this.averageLabel,
  });
  final LeagueMatch league;
  final int index;
  final List<Widget> actions;
  final String? boardLabel;
  final String? averageLabel;
  @override
  Widget build(BuildContext context) {
    final game = league.games[index];
    final home = game.home.map((i) => league.homePlayers[i]).join(' / ');
    final away = game.away.map((i) => league.awayPlayers[i]).join(' / ');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                Text(
                  'Spiel ${index + 1} · ${game.isDouble ? 'Doppel' : 'Einzel'}',
                ),
                Text(boardLabel ?? (game.complete ? 'Abgeschlossen' : 'Offen')),
              ],
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final score = Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    game.complete
                        ? '${game.homeLegs}:${game.awayLegs}'
                        : '– : –',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                );
                if (constraints.maxWidth < 600) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        home,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: score,
                      ),
                      Text(
                        away,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(
                      child: Text(
                        home,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    score,
                    Expanded(
                      child: Text(
                        away,
                        textAlign: TextAlign.end,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 12),
            if (averageLabel != null) Text(averageLabel!),
            Wrap(spacing: 8, runSpacing: 8, children: actions),
          ],
        ),
      ),
    );
  }
}
