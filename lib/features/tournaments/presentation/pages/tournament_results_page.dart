import 'package:flutter/material.dart';

import '../../domain/tournament_models.dart';

class TournamentResultsPage extends StatelessWidget {
  const TournamentResultsPage({super.key, required this.tournament});

  final CreatedTournament tournament;

  @override
  Widget build(BuildContext context) {
    final summary = _TournamentResultSummary.fromTournament(tournament);
    final podium = summary.ranking.take(3).toList();
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Turnierergebnisse'),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.of(context).popUntil(
              (route) => route.isFirst,
            ),
            icon: const Icon(Icons.home_outlined),
            label: const Text('Hauptmenue'),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              color: colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Icon(
                      Icons.emoji_events,
                      size: 52,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      tournament.name,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    const Text('Turnier abgeschlossen'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Podium',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            if (podium.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Es liegen noch keine Ergebnisse vor.'),
                ),
              )
            else
              _Podium(ranking: podium),
            const SizedBox(height: 24),
            Text(
              'Turnierstatistik',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _StatisticsGrid(summary: summary),
            const SizedBox(height: 24),
            Text(
              'Gesamtwertung',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              summary.rankingHint,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  for (var index = 0; index < summary.ranking.length; index++)
                    _RankingRow(
                      place: index + 1,
                      stats: summary.ranking[index],
                      maxLegs: summary.maxLegs,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Podium extends StatelessWidget {
  const _Podium({required this.ranking});

  final List<_PlayerResultStats> ranking;

  @override
  Widget build(BuildContext context) {
    const medals = [Icons.looks_one, Icons.looks_two, Icons.looks_3];
    const colors = [Color(0xffffc107), Color(0xffb0bec5), Color(0xffcd7f32)];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var index = 0; index < ranking.length; index++)
          Expanded(
            child: Card(
              color: colors[index].withValues(alpha: .18),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 14,
                ),
                child: Column(
                  children: [
                    Icon(medals[index], size: 34, color: colors[index]),
                    const SizedBox(height: 6),
                    Text(
                      '${index + 1}. Platz',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      ranking[index].player.name,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _StatisticsGrid extends StatelessWidget {
  const _StatisticsGrid({required this.summary});

  final _TournamentResultSummary summary;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _StatisticCard(label: 'Spieler', value: '${summary.playerCount}'),
        _StatisticCard(label: 'Spiele', value: '${summary.matchCount}'),
        _StatisticCard(label: 'Legs', value: '${summary.legCount}'),
        _StatisticCard(
          label: 'Legs / Spiel',
          value: summary.matchCount == 0
              ? '–'
              : (summary.legCount / summary.matchCount).toStringAsFixed(1),
        ),
      ],
    );
  }
}

class _StatisticCard extends StatelessWidget {
  const _StatisticCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 4),
              Text(
                value,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RankingRow extends StatelessWidget {
  const _RankingRow({
    required this.place,
    required this.stats,
    required this.maxLegs,
  });

  final int place;
  final _PlayerResultStats stats;
  final int maxLegs;

  @override
  Widget build(BuildContext context) {
    final value = maxLegs == 0 ? 0.0 : stats.legsFor / maxLegs;
    return ListTile(
      leading: CircleAvatar(child: Text('$place')),
      title: Text(stats.player.name),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${stats.wins} Siege · ${stats.losses} Niederlagen · ${stats.legsFor}:${stats.legsAgainst} Legs'),
          const SizedBox(height: 5),
          LinearProgressIndicator(value: value),
        ],
      ),
      isThreeLine: true,
    );
  }
}

class _TournamentResultSummary {
  _TournamentResultSummary({
    required this.ranking,
    required this.matchCount,
    required this.legCount,
    required this.playerCount,
    required this.rankingHint,
  });

  final List<_PlayerResultStats> ranking;
  final int matchCount;
  final int legCount;
  final int playerCount;
  final String rankingHint;

  int get maxLegs => ranking.fold(0, (max, item) => item.legsFor > max ? item.legsFor : max);

  factory _TournamentResultSummary.fromTournament(CreatedTournament tournament) {
    final stats = {
      for (final player in tournament.players) player.name: _PlayerResultStats(player),
    };
    var matchCount = 0;
    var legCount = 0;

    for (final stage in tournament.runStages) {
      for (final match in _matchesFor(stage)) {
        if (!match.hasResult) continue;
        final home = match.homePlayer!;
        final away = match.awayPlayer!;
        final homeStats = stats.putIfAbsent(home.name, () => _PlayerResultStats(home));
        final awayStats = stats.putIfAbsent(away.name, () => _PlayerResultStats(away));
        final homeLegs = match.homeLegs!;
        final awayLegs = match.awayLegs!;
        matchCount++;
        legCount += homeLegs + awayLegs;
        homeStats.legsFor += homeLegs;
        homeStats.legsAgainst += awayLegs;
        awayStats.legsFor += awayLegs;
        awayStats.legsAgainst += homeLegs;
        if (homeLegs > awayLegs) {
          homeStats.wins++;
          awayStats.losses++;
        } else if (awayLegs > homeLegs) {
          awayStats.wins++;
          homeStats.losses++;
        }
      }
    }

    final finalStage = tournament.runStages.isEmpty
        ? null
        : tournament.runStages.last;
    final finalStageRanking = finalStage is KnockoutTournamentRunStage
        ? _knockoutRanking(finalStage)
        : const <TournamentPlayer>[];
    final ranking = <_PlayerResultStats>[];
    for (final player in finalStageRanking) {
      final entry = stats[player.name];
      if (entry != null) ranking.add(entry);
    }
    final remaining = stats.values.where((entry) => !ranking.contains(entry)).toList()
      ..sort(_compareStats);
    ranking.addAll(remaining);

    return _TournamentResultSummary(
      ranking: ranking,
      matchCount: matchCount,
      legCount: legCount,
      playerCount: tournament.players.length,
      rankingHint: finalStage is KnockoutTournamentRunStage
          ? 'Die Platzierung folgt dem finalen K.-o.-Baum; die Balken zeigen gewonnene Legs im gesamten Turnier.'
          : 'Die Platzierung folgt den Gesamtwerten aus allen eingetragenen Spielen.',
    );
  }

  static int _compareStats(_PlayerResultStats a, _PlayerResultStats b) {
    final wins = b.wins.compareTo(a.wins);
    if (wins != 0) return wins;
    final difference = b.legDifference.compareTo(a.legDifference);
    if (difference != 0) return difference;
    final legs = b.legsFor.compareTo(a.legsFor);
    if (legs != 0) return legs;
    return a.player.name.compareTo(b.player.name);
  }

  static List<GroupMatch> _matchesFor(TournamentRunStage stage) {
    if (stage is KnockoutTournamentRunStage) return stage.matches;
    if (stage is GroupTournamentRunStage) {
      return [for (final group in stage.groups) ...group.matches];
    }
    return const [];
  }

  static List<TournamentPlayer> _knockoutRanking(
    KnockoutTournamentRunStage stage,
  ) {
    final ranking = <TournamentPlayer>[];
    void add(TournamentPlayer? player) {
      if (player != null && !ranking.any((entry) => entry.name == player.name)) {
        ranking.add(player);
      }
    }

    if (stage.eliminationLossLimit > 1) {
      final losses = <String, int>{};
      final lastRound = <String, int>{};
      final players = <TournamentPlayer>[];
      for (final round in stage.rounds) {
        for (final match in round) {
          addUnique(players, match.homePlayer);
          addUnique(players, match.awayPlayer);
          if (!match.hasResult) continue;
          final loser = match.loser;
          final winner = match.winner;
          if (loser != null) losses[loser.name] = (losses[loser.name] ?? 0) + 1;
          if (loser != null) lastRound[loser.name] = match.round;
          if (winner != null) lastRound[winner.name] = match.round;
        }
      }
      players.sort((a, b) {
        final lossComparison = (losses[a.name] ?? 0).compareTo(losses[b.name] ?? 0);
        if (lossComparison != 0) return lossComparison;
        final roundComparison = (lastRound[b.name] ?? 0).compareTo(lastRound[a.name] ?? 0);
        if (roundComparison != 0) return roundComparison;
        return a.name.compareTo(b.name);
      });
      return players;
    }

    if (stage.rounds.isNotEmpty) {
      final finalRound = stage.rounds.last;
      if (finalRound.length == 1) {
        add(finalRound.first.winner);
        add(finalRound.first.loser);
      } else {
        for (final match in finalRound) add(match.winner);
      }
      for (final match in stage.placementMatches.where((match) => match.label == 'Spiel um Platz 3')) {
        add(match.winner);
        add(match.loser);
      }
      for (var roundIndex = stage.rounds.length - 2; roundIndex >= 0; roundIndex--) {
        for (final match in stage.rounds[roundIndex]) add(match.loser);
      }
    }
    return ranking;
  }

  static void addUnique(List<TournamentPlayer> players, TournamentPlayer? player) {
    if (player != null && !players.any((entry) => entry.name == player.name)) {
      players.add(player);
    }
  }
}

class _PlayerResultStats {
  _PlayerResultStats(this.player);

  final TournamentPlayer player;
  int wins = 0;
  int losses = 0;
  int legsFor = 0;
  int legsAgainst = 0;

  int get legDifference => legsFor - legsAgainst;
}
