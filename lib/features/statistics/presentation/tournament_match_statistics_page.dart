import 'package:flutter/material.dart';
import '../../../shared/widgets/adaptive_content.dart';
import '../../tournaments/domain/tournament_models.dart';

/// Read-only details derived from the statistics saved with this match.
class TournamentMatchStatisticsPage extends StatelessWidget {
  const TournamentMatchStatisticsPage({super.key, required this.match});
  final GroupMatch match;

  @override
  Widget build(BuildContext context) {
    final sides = [match.homePlayer, match.awayPlayer];
    final duration = match.startedAt != null && match.finishedAt != null
        ? match.finishedAt!.difference(match.startedAt!)
        : null;
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
