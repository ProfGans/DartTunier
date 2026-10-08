import 'package:flutter/material.dart';
import '../../../shared/widgets/adaptive_content.dart';
import '../../tournaments/domain/tournament_models.dart';
import '../domain/match_scorer_summary.dart';

/// Read-only details derived from the statistics saved with this match.
class TournamentMatchStatisticsPage extends StatelessWidget {
  const TournamentMatchStatisticsPage({super.key, required this.match});
  final GroupMatch match;

  @override
  Widget build(BuildContext context) {
    final summary = MatchScorerSummary.fromMatch(match);
    final sides = [match.homePlayer, match.awayPlayer];
    final duration = match.startedAt != null && match.finishedAt != null
        ? match.finishedAt!.difference(match.startedAt!)
        : null;
    String number(double? value) =>
        value?.toStringAsFixed(2).replaceAll('.', ',') ?? '–';
    return Scaffold(
      appBar: AppBar(title: const Text('Spielstatistik')),
      body: AdaptiveContentList(
        children: [
          Text(
            '${sides[0]?.name ?? 'Offen'} gegen ${sides[1]?.name ?? 'Offen'}',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          Text(
            'Ergebnis: ${match.homeScore}:${match.awayScore}',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          if (match.homeSets != null)
            Text('Legs: ${match.homeLegs}:${match.awayLegs}'),
          if (duration != null && !duration.isNegative)
            Text(
              'Spieldauer: ${duration.inMinutes} min ${duration.inSeconds % 60} s',
            ),
          const SizedBox(height: 16),
          if (summary == null)
            const Text(
              'Für dieses Spiel wurden keine Scorer-Aufnahmen gespeichert. Bei manuell eingetragenen Ergebnissen stehen keine Wurfstatistiken zur Verfügung.',
            ),
          if (sides.any((p) => p?.bot != null))
            const Text('Für Bots werden keine Statistiken gespeichert.'),
          if (summary != null)
            AdaptiveTileLayout(
              children: [
                for (var i = 0; i < sides.length; i++)
                  if (sides[i]?.bot == null)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              sides[i]?.name ?? 'Spieler',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              '3-Dart-Average: ${number(summary.players[i].average)}',
                            ),
                            Text(
                              'First-9-Average: ${number(summary.players[i].firstNineAverage)}',
                            ),
                            Text('Darts: ${summary.players[i].darts}'),
                            Text('Aufnahmen: ${summary.players[i].visits}'),
                            Text(
                              'Höchste Aufnahme: ${summary.players[i].highestScore}',
                            ),
                            Text('180er: ${summary.players[i].scores180}'),
                            Text(
                              'Höchstes Finish: ${summary.players[i].highestFinish}',
                            ),
                            Text(
                              'Bestes Leg: ${summary.players[i].bestLeg == null ? '–' : '${summary.players[i].bestLeg} Darts'}',
                            ),
                            Text(
                              'Legs gewonnen: ${summary.players[i].legsWon}',
                            ),
                            Text('Überworfen: ${summary.players[i].busts}'),
                            if (match
                                    .deviceResult?['statistics']?['doubleOut'] ==
                                true)
                              Text(
                                'Checkoutquote: ${summary.players[i].unknownCheckoutVisits > 0 ? 'Unvollständige Angaben' : '${number(summary.players[i].checkoutPercent)} %'}',
                              ),
                          ],
                        ),
                      ),
                    ),
              ],
            ),
        ],
      ),
    );
  }
}

class MatchStatisticsTapTarget extends StatelessWidget {
  const MatchStatisticsTapTarget({
    super.key,
    required this.match,
    required this.child,
  });
  final GroupMatch match;
  final Widget child;
  static void open(BuildContext context, GroupMatch match) =>
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => TournamentMatchStatisticsPage(match: match),
        ),
      );
  @override
  Widget build(BuildContext context) =>
      !match.hasResult || !match.hasPlayers || match.isAnnulled
      ? child
      : Tooltip(
          message: 'Spielstatistik öffnen',
          child: Material(
            color: Colors.transparent,
            child: InkWell(onTap: () => open(context, match), child: child),
          ),
        );
}
