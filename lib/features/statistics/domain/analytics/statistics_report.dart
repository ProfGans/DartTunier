import 'dart:math' as math;
import '../saved_scorer_match.dart';
import '../statistics_period.dart';
import '../league_statistics_entries.dart';
import '../../../tournaments/domain/tournament_models.dart';
import 'statistics_metric.dart';

class StatisticsObservation {
  StatisticsObservation({
    required this.id,
    required this.playerId,
    required this.name,
    required this.label,
    required this.date,
    required Map<String, double> values,
    this.opponent = '',
    this.result,
    this.estimatedDate = false,
    this.doubleMatch = false,
    this.startScore,
  }) : values = Map.unmodifiable(values);
  final String id, playerId, name, label, opponent;
  final DateTime date;
  final Map<String, double> values;
  final String? result;
  final bool estimatedDate, doubleMatch;
  final int? startScore;
}

class StatisticsReport {
  StatisticsReport(Iterable<StatisticsObservation> source)
    : observations = List.unmodifiable(
        ({for (final o in source) '${o.playerId}:${o.id}': o}.values.toList()
          ..sort((a, b) {
            final date = a.date.compareTo(b.date);
            return date == 0 ? a.id.compareTo(b.id) : date;
          })),
      );
  StatisticsReport._sorted(Iterable<StatisticsObservation> source)
    : observations = List.unmodifiable(source);
  final List<StatisticsObservation> observations;
  final _values = <StatisticsMetric, double?>{};
  final _series = <StatisticsMetric, List<(StatisticsObservation, double)>>{};
  late final Map<String, StatisticsReport> byPlayer = _groupPlayers();
  Map<String, StatisticsReport> _groupPlayers() {
    final groups = <String, List<StatisticsObservation>>{};
    for (final observation in observations) {
      groups.putIfAbsent(observation.playerId, () => []).add(observation);
    }
    return Map.unmodifiable(
      groups.map((id, rows) => MapEntry(id, StatisticsReport._sorted(rows))),
    );
  }

  final _cumulative = <StatisticsMetric, List<double>>{};
  ({StatisticsPeriod? period, bool? doubles, int? score})? _filterKey;
  StatisticsReport? _filtered;
  StatisticsReport filtered({
    StatisticsPeriod? period,
    Set<String>? players,
    bool? doubleMatch,
    int? startScore,
  }) {
    if (players == null &&
        period == null &&
        doubleMatch == null &&
        startScore == null) {
      return this;
    }
    if (players?.length == 1) {
      return (byPlayer[players!.single] ?? StatisticsReport(const [])).filtered(
        period: period,
        doubleMatch: doubleMatch,
        startScore: startScore,
      );
    }
    final key = (period: period, doubles: doubleMatch, score: startScore);
    if (players == null && _filterKey == key && _filtered != null) {
      return _filtered!;
    }
    final result = StatisticsReport._sorted(
      observations.where(
        (o) =>
            (period == null || (!o.estimatedDate && period.contains(o.date))) &&
            (players == null || players.contains(o.playerId)) &&
            (doubleMatch == null || o.doubleMatch == doubleMatch) &&
            (startScore == null || o.startScore == startScore),
      ),
    );
    if (players == null) {
      _filterKey = key;
      _filtered = result;
    }
    return result;
  }

  /// Aggregate each prefix once, instead of rescanning for every chart point.
  List<double> cumulative(StatisticsMetric metric) =>
      _cumulative.putIfAbsent(metric, () {
        var numerator = 0.0, denominator = 0.0;
        double? extreme;
        final result = <double>[];
        for (final (observation, individual) in series(metric)) {
          numerator += observation.values[metric.id]!;
          denominator += observation.values[metric.denominator] ?? 0;
          extreme = extreme == null
              ? individual
              : metric.aggregation == MetricAggregation.minimum
              ? math.min(extreme, individual)
              : math.max(extreme, individual);
          result.add(switch (metric.aggregation) {
            MetricAggregation.sum => numerator,
            MetricAggregation.ratio => metric.factor * numerator / denominator,
            MetricAggregation.minimum || MetricAggregation.maximum => extreme,
          });
        }
        return List.unmodifiable(result);
      });
  double? value(
    StatisticsMetric metric, [
    Iterable<StatisticsObservation>? source,
  ]) => source == null
      ? _values.putIfAbsent(metric, () => _value(metric, observations))
      : _value(metric, source);

  double? _value(
    StatisticsMetric metric,
    Iterable<StatisticsObservation> source,
  ) {
    final rows = source.where((o) => o.values.containsKey(metric.id)).toList();
    if (rows.isEmpty) return null;
    if (metric.id == 'finishes' &&
        metric.denominator == 'attempts' &&
        rows.any((o) => (o.values['unknownAttempts'] ?? 0) > 0)) {
      return null;
    }
    final numbers = rows.map((o) => o.values[metric.id]!);
    if (metric.aggregation == MetricAggregation.maximum) {
      return numbers.reduce((a, b) => a > b ? a : b);
    }
    if (metric.aggregation == MetricAggregation.minimum) {
      return numbers.reduce((a, b) => a < b ? a : b);
    }
    if (metric.aggregation == MetricAggregation.ratio) {
      final eligible = rows.where(
        (o) => o.values.containsKey(metric.denominator),
      );
      final denominator = eligible.fold<double>(
        0,
        (sum, o) => sum + o.values[metric.denominator]!,
      );
      return denominator == 0
          ? null
          : metric.factor *
                eligible.fold<double>(
                  0,
                  (sum, o) => sum + o.values[metric.id]!,
                ) /
                denominator;
    }
    return numbers.fold<double>(0, (sum, v) => sum + v);
  }

  ({double? min, double? max, double? median, double? deviation}) distribution(
    StatisticsMetric metric,
  ) {
    final numbers = series(metric).map((p) => p.$2).toList()..sort();
    if (numbers.isEmpty) {
      return (min: null, max: null, median: null, deviation: null);
    }
    final mean =
        numbers.fold<double>(0, (sum, value) => sum + value) / numbers.length;
    final deviation = math.sqrt(
      numbers.fold<double>(0, (sum, value) => sum + math.pow(value - mean, 2)) /
          numbers.length,
    );
    final middle = numbers.length ~/ 2;
    return (
      min: numbers.first,
      max: numbers.last,
      median: numbers.length.isOdd
          ? numbers[middle]
          : (numbers[middle - 1] + numbers[middle]) / 2,
      deviation: deviation,
    );
  }

  List<({double lower, double upper, int count})> histogram(
    StatisticsMetric metric,
  ) {
    final numbers = series(metric).map((p) => p.$2).toList()..sort();
    if (numbers.isEmpty) return [];
    final range = numbers.last - numbers.first;
    if (range == 0) {
      return [
        (lower: numbers.first, upper: numbers.last, count: numbers.length),
      ];
    }
    return [
      for (var bucket = 0; bucket < 5; bucket++)
        (
          lower: numbers.first + range * bucket / 5,
          upper: numbers.first + range * (bucket + 1) / 5,
          count: numbers
              .where(
                (v) =>
                    v >= numbers.first + range * bucket / 5 &&
                    (bucket == 4
                        ? v <= numbers.last
                        : v < numbers.first + range * (bucket + 1) / 5),
              )
              .length,
        ),
    ];
  }

  List<(StatisticsObservation, double)> series(StatisticsMetric metric) =>
      _series.putIfAbsent(
        metric,
        () => List.unmodifiable([
          for (final o in observations)
            if (value(metric, [o]) case final double v) (o, v),
        ]),
      );
  late final List<StatisticsObservation> completed = List.unmodifiable(
    observations.where((o) => o.result != null),
  );
  late final List<String> form = List.unmodifiable(
    completed.reversed
        .take(10)
        .map((o) => o.result!)
        .toList()
        .reversed
        .toList(),
  );
  int get winningStreak {
    var count = 0;
    for (final o in completed.reversed) {
      if (o.result != 'S') break;
      count++;
    }
    return count;
  }

  ({
    double? recent,
    double? previous,
    double? delta,
    int recentCount,
    int previousCount,
  })
  trend(StatisticsMetric metric) {
    final eligible = observations
        .where((o) => value(metric, [o]) != null)
        .toList();
    final recent = eligible.reversed.take(5).toList();
    final previous = eligible.reversed.skip(5).take(5).toList();
    final a = value(metric, recent), b = value(metric, previous);
    return (
      recent: a,
      previous: b,
      delta: a == null || b == null ? null : a - b,
      recentCount: recent.length,
      previousCount: previous.length,
    );
  }
}

class StatisticsAnalytics {
  const StatisticsAnalytics();
  StatisticsReport scorer(Iterable<SavedScorerMatch> matches) =>
      StatisticsReport([
        for (final m in {for (final m in matches) m.id: m}.values)
          if (m.statistics.visits > 0 || m.thrownDarts > 0) _scorer(m),
      ]);
  StatisticsObservation _scorer(SavedScorerMatch m) {
    final p = m.statistics;
    final finished = m.winner != null || m.isDraw;
    final result = !finished
        ? null
        : m.isDraw
        ? 'U'
        : m.winner == m.playerIndex
        ? 'S'
        : 'N';
    final values = <String, double>{
      'sessions': 1,
      'scorerGames': 1,
      'incomplete': finished ? 0 : 1,
      'doubleOutGames': m.doubleOut ? 1 : 0,
      'points': p.points.toDouble(),
      'darts': p.darts.toDouble(),
      'thrownDarts': m.thrownDarts.toDouble(),
      'estimatedThrownDarts': m.estimatedThrownDarts.toDouble(),
      'visits': p.visits.toDouble(),
      'firstPoints': p.firstNinePoints.toDouble(),
      'firstDarts': p.firstNineDarts.toDouble(),
      'scores60': p.scores60.toDouble(),
      'scores100': p.scores100.toDouble(),
      'scores140': p.scores140.toDouble(),
      'scores180': p.scores180.toDouble(),
      'highestScore': p.highestScore.toDouble(),
      'busts': p.busts.toDouble(),
      'legsWon': p.legsWon.toDouble(),
      'legsLost': (p.legsPlayed - p.legsWon).toDouble(),
      'legs': p.legsPlayed.toDouble(),
      'highestFinish': p.highestFinish.toDouble(),
      'tonFinishes': p.tonFinishes.toDouble(),
      'scorerLegsWon': p.legsWon.toDouble(),
      'wonLegDarts': p.wonLegDarts.toDouble(),
      'breaks': p.breaks.toDouble(),
      'holds': p.holds.toDouble(),
      'shortLegs': p.shortLegs.values.fold<int>(0, (s, v) => s + v).toDouble(),
      'nineDarters': p.nineDarters.toDouble(),
      if (p.bestLeg != null) 'bestLeg': p.bestLeg!.toDouble(),
      if (m.doubleOut) ...{
        'finishes': p.legsWon.toDouble(),
        'attempts': p.checkoutAttempts.toDouble(),
        'unknownAttempts': p.unknownCheckoutVisits.toDouble(),
      },
      if (finished) ..._results(result!, 1),
    };
    return StatisticsObservation(
      id: m.id,
      playerId: m.accountId,
      name: m.names[m.playerIndex],
      label: m.names.join(' · '),
      date: m.playedAt,
      opponent: [
        for (var i = 0; i < m.names.length; i++)
          if (i != m.playerIndex) m.names[i],
      ].join(' · '),
      result: result,
      values: values,
      startScore: m.startScores[m.playerIndex],
    );
  }

  Map<String, double> _results(String result, int count) => {
    'sessions': count.toDouble(),
    'incomplete': 0,
    'matches': count.toDouble(),
    'wins': result == 'S' ? 1 : 0,
    'losses': result == 'N' ? 1 : 0,
    'draws': result == 'U' ? 1 : 0,
  };
  StatisticsReport tournaments(
    Iterable<CreatedTournament> source, {
    Map<String, String> aliases = const {},
  }) {
    final observations = <StatisticsObservation>[];
    for (final t in {for (final t in source) t.id: t}.values) {
      var entryIndex = 0;
      for (final e in leagueStatisticsEntries(t)) {
        final result = e.ownLegs > e.otherLegs
            ? 'S'
            : e.ownLegs == e.otherLegs
            ? 'U'
            : 'N';
        observations.add(
          StatisticsObservation(
            id: '${t.id}:league:${entryIndex++}',
            playerId: aliases[e.id] ?? e.id,
            name: e.name,
            label: t.name,
            date: t.finishedAt ?? t.startedAt ?? t.createdAt,
            estimatedDate: t.finishedAt == null && t.startedAt == null,
            doubleMatch: e.isDouble,
            result: result,
            values: {
              ..._results(result, 1),
              'scorerGames': 0,
              'legsWon': e.ownLegs.toDouble(),
              'legsLost': e.otherLegs.toDouble(),
              'legs': (e.ownLegs + e.otherLegs).toDouble(),
            },
          ),
        );
      }
      final seen = <GroupMatch>{};
      var index = 0;
      for (final stage in t.runStages) {
        final matches = <GroupMatch>{};
        if (stage is KnockoutTournamentRunStage) matches.addAll(stage.matches);
        if (stage is GroupTournamentRunStage) {
          for (final g in stage.groups) {
            matches.addAll(g.matches);
            matches.addAll(g.placementMatches);
          }
        }
        for (final match in matches) {
          if (!seen.add(match)) continue;
          final matchId = '${t.id}:match:${index++}';
          if (!match.countsForStatistics || !match.hasPlayers || match.isAnnulled) {
            continue;
          }
          final players = [match.homePlayer!, match.awayPlayer!];
          for (var side = 0; side < 2; side++) {
            final player = players[side];
            if (player.bot != null) continue;

            final own = side == 0 ? match.homeScore! : match.awayScore!,
                other = side == 0 ? match.awayScore! : match.homeScore!;
            final result = own > other
                ? 'S'
                : own == other
                ? 'U'
                : 'N';
            final legs = side == 0 ? match.homeLegs : match.awayLegs,
                lost = side == 0 ? match.awayLegs : match.homeLegs;
            final sets = side == 0 ? match.homeSets : match.awaySets,
                lostSets = side == 0 ? match.awaySets : match.homeSets;
            final values = <String, double>{
              ..._results(result, 1),
              'scorerGames': 0,
              if (legs != null && lost != null) ...{
                'legsWon': legs.toDouble(),
                'legsLost': lost.toDouble(),
                'legs': (legs + lost).toDouble(),
              },
              if (sets != null && lostSets != null) ...{
                'setsWon': sets.toDouble(),
                'setsLost': lostSets.toDouble(),
              },
            };
            final raw = match.deviceResult?['statistics'];
            int? startScore;
            if (raw is Map && !player.isTeam) {
              final saved = SavedScorerMatch.fromJson({
                ...Map<String, dynamic>.from(raw),
                'playerIndex': side,
              });
              if (saved.statistics.visits > 0) {
                final scoring = _scorer(saved);
                startScore = scoring.startScore;
                for (final e in scoring.values.entries) {
                  if (!{
                    'sessions',
                    'incomplete',
                    'matches',
                    'wins',
                    'losses',
                    'draws',
                    'legsWon',
                    'legsLost',
                    'legs',
                  }.contains(e.key)) {
                    values[e.key] = e.value;
                  }
                }
              }
            }
            for (final individual in player.individuals) {
              final rawId =
                  individual.profileId ?? 'unlinked:${t.id}:${individual.name}';
              final id = aliases[rawId] ?? rawId;
              observations.add(
                StatisticsObservation(
                  id: matchId,
                  playerId: id,
                  name: individual.name,
                  label:
                      '${t.name} · ${players.map((p) => p.name).join(' – ')}',
                  opponent: players[1 - side].name,
                  date: match.finishedAt ?? match.startedAt ?? t.createdAt,
                  estimatedDate:
                      match.finishedAt == null && match.startedAt == null,
                  result: result,
                  values: values,
                  startScore: startScore,
                  doubleMatch: player.isTeam || players[1 - side].isTeam,
                ),
              );
            }
          }
        }
      }
    }
    return StatisticsReport(observations);
  }
}
