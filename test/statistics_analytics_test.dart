import 'package:dart_tournament_manager/features/tournaments/domain/tournament_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_tournament_manager/features/statistics/domain/analytics/statistics_metric.dart';
import 'package:dart_tournament_manager/features/statistics/domain/analytics/statistics_report.dart';
import 'package:dart_tournament_manager/features/statistics/domain/statistics_period.dart';
import 'package:dart_tournament_manager/features/statistics/domain/saved_scorer_match.dart';
import 'package:dart_tournament_manager/features/scorer/domain/scorer_statistics.dart';
import 'package:dart_tournament_manager/features/communities/domain/community_statistics.dart';
import 'community_tournament_elo_test.dart' show eloTournament, eloMembers;
import 'league_statistics_test.dart' show fixture;

StatisticsMetric metric(String title) =>
    statisticsMetrics.firstWhere((m) => m.title == title);
SavedScorerMatch analyticsMatch({
  String id = 'one',
  int points = 60,
  int darts = 3,
  int? attempts = 0,
  int? winner = 0,
  bool draw = false,
  bool doubleOut = true,
}) => SavedScorerMatch(
  id: id,
  accountId: 'a',
  playedAt: DateTime(2026, 10, int.tryParse(id) ?? 1),
  playerIndex: 0,
  names: const ['Anna', 'Ben'],
  startScores: const [501, 501],
  standard501Rules: true,
  doubleOut: doubleOut,
  winner: winner,
  isDraw: draw,
  visits: [
    ScorerVisit(
      player: 0,
      leg: 0,
      starter: 0,
      points: points,
      darts: darts,
      remaining: 501 - points,
      bust: false,
      checkoutAttempts: attempts,
    ),
  ],
);
void main() {
  const engine = StatisticsAnalytics();
  test(
    'team results reach individual profiles without inventing individual averages',
    () {
      final t = eloTournament(completed: true);
      final match = (t.runStages.first as dynamic).groups.first.matches.first;
      match.homePlayer = TournamentPlayer.team([
        match.homePlayer as TournamentPlayer,
        const TournamentPlayer(
          profileId: 'c',
          name: 'Partner',
          isGenerated: false,
        ),
      ]);
      match.awayPlayer = TournamentPlayer.team([
        match.awayPlayer as TournamentPlayer,
        const TournamentPlayer(
          profileId: 'd',
          name: 'Partner',
          isGenerated: false,
        ),
      ]);
      match.deviceResult = {'statistics': analyticsMatch(points: 180).toJson()};
      final report = engine.tournaments([t]);
      expect(report.observations.length, 4);
      expect(
        report
            .filtered(players: {'a'}, doubleMatch: true)
            .value(metric('Siege')),
        1,
      );
      expect(report.value(metric('3-Dart-Average')), isNull);
    },
  );
  test('distributions and histogram preserve exact counts', () {
    final report = engine.scorer([
      analyticsMatch(id: '1', points: 30),
      analyticsMatch(id: '2', points: 60),
      analyticsMatch(id: '3', points: 90),
    ]);
    final summary = report.distribution(metric('3-Dart-Average'));
    expect(summary.min, 30);
    expect(summary.max, 90);
    expect(summary.median, 60);
    expect(summary.deviation, closeTo(24.4949, .001));
    expect(
      report
          .histogram(metric('3-Dart-Average'))
          .fold<int>(0, (sum, bucket) => sum + bucket.count),
      3,
    );
    expect(report.histogram(metric('Spiele')).length, 1);
    expect(report.value(metric('Scorer-Datenabdeckung')), 100);
  });
  test('undated legacy results only appear in overall view', () {
    final report = engine.tournaments([eloTournament(completed: true)]);
    expect(report.observations, isNotEmpty);
    expect(
      report
          .filtered(
            period: StatisticsPeriod(DateTime(2026), DateTime(2026, 12, 31)),
          )
          .observations,
      isEmpty,
    );
  });
  test('real completed leg yields correct finishing and leg quality', () {
    final saved = SavedScorerMatch(
      id: 'finish',
      accountId: 'a',
      playedAt: DateTime(2026),
      playerIndex: 0,
      names: const ['Anna', 'Ben'],
      startScores: const [501, 501],
      standard501Rules: true,
      doubleOut: true,
      winner: 0,
      visits: [
        for (var i = 0; i < 3; i++)
          ScorerVisit(
            player: 0,
            leg: 0,
            starter: 1,
            points: i == 2 ? 141 : 180,
            darts: 3,
            remaining: i == 0
                ? 321
                : i == 1
                ? 141
                : 0,
            bust: false,
            checkoutAttempts: i == 2 ? 2 : 0,
          ),
      ],
    );
    final report = engine.scorer([saved]);
    expect(report.value(metric('Checkoutquote')), 50);
    expect(report.value(metric('Bestes Leg')), 9);
    expect(report.value(metric('Darts je gewonnenem Leg')), 9);
    expect(report.value(metric('Höchstes Finish')), 141);
    expect(report.value(metric('100+ Finishes')), 1);
    expect(report.value(metric('Breaks')), 1);
    expect(report.value(metric('Holds')), 0);
    expect(report.value(metric('9-Darter')), 1);
  });
  test(
    'transferred scorer visits are used, result counts remain tournament-owned',
    () {
      final t = eloTournament(completed: true);
      final match = (t.runStages.first as dynamic).groups.first.matches.first;
      match.deviceResult = {'statistics': analyticsMatch(points: 180).toJson()};
      final report = engine.tournaments([t]).filtered(players: {'a'});
      expect(report.value(metric('3-Dart-Average')), 180);
      expect(report.value(metric('Gewonnene Legs')), 3);
      expect(report.value(metric('Spiele')), 1);
    },
  );
  test('weighted averages, threshold overlap and distinct maxima', () {
    final report = engine.scorer([
      analyticsMatch(points: 180),
      analyticsMatch(id: '2', points: 40, darts: 1),
    ]);
    expect(report.value(metric('3-Dart-Average')), 165);
    expect(report.value(metric('180er')), 1);
    expect(report.value(metric('60+ Aufnahmen')), 1);
    expect(report.value(metric('Höchste Aufnahme')), 180);
    expect(report.value(metric('180er je 100 Aufnahmen')), 50);
  });
  test('draw, incomplete sessions and deduplication preserve result form', () {
    final incomplete = analyticsMatch(id: '3', winner: null);
    final report = engine.scorer([
      analyticsMatch(),
      analyticsMatch(id: '2', winner: null, draw: true),
      incomplete,
      incomplete,
    ]);
    expect(report.observations.length, 3);
    expect(report.value(metric('Spiele')), 2);
    expect(report.value(metric('Aufnahmen')), 3);
    expect(report.value(metric('Siegquote')), 50);
    expect(report.form, ['S', 'U']);
  });
  test(
    'unknown checkout attempts block totals, non double-out is excluded',
    () {
      final report = engine.scorer([
        analyticsMatch(attempts: null),
        analyticsMatch(id: '2', attempts: 2, doubleOut: false),
      ]);
      expect(report.value(metric('Checkoutquote')), isNull);
      expect(report.value(metric('Checkoutversuche')), 0);
      expect(report.value(metric('Unbekannte Checkout-Aufnahmen')), 1);
    },
  );
  test('empty data is absent rather than fabricated zero', () {
    final report = StatisticsReport([]);
    for (final m in statisticsMetrics) {
      expect(report.value(m), isNull);
    }
  });
  test(
    'recent five versus prior five uses weighted input and excludes missing',
    () {
      final report = engine.scorer([
        for (var i = 1; i <= 10; i++)
          analyticsMatch(id: '$i', points: i <= 5 ? 30 : 90),
      ]);
      final trend = report.trend(metric('3-Dart-Average'));
      expect(trend.recent, 90);
      expect(trend.previous, 30);
      expect(trend.delta, 60);
      expect(report.winningStreak, 10);
      expect(
        report
            .filtered(
              period: StatisticsPeriod(
                DateTime(2026, 10, 6),
                DateTime(2026, 10, 10),
              ),
            )
            .observations
            .length,
        5,
      );
    },
  );
  test(
    'tournament results obey identity and correction; score-only has no average',
    () {
      final t = eloTournament(completed: true);
      final report = engine
          .tournaments([t, t], aliases: {'a': 'linked'})
          .filtered(players: {'linked'});
      expect(report.value(metric('Spiele')), 1);
      expect(report.value(metric('Gewonnene Legs')), 3);
      expect(report.value(metric('3-Dart-Average')), isNull);
      expect(report.observations.single.estimatedDate, isTrue);
      final match = (t.runStages.first as dynamic).groups.first.matches.first;
      match.homeLegs = 0;
      match.awayLegs = 3;
      expect(
        engine
            .tournaments([t], aliases: {'a': 'linked'})
            .filtered(players: {'linked'})
            .form,
        ['N'],
      );
      match.isAnnulled = true;
      expect(engine.tournaments([t]).observations, isEmpty);
    },
  );
  test('community scopes results and excludes private sessions', () {
    final t = eloTournament(completed: true);
    final scoped = CommunityStatistics(
      communityId: 'different',
      members: eloMembers,
      tournaments: [t],
    );
    expect(engine.tournaments(scoped.tournaments).observations, isEmpty);
  });
  test(
    'league doubles retain separate participants and missing scorer data',
    () {
      final t = fixture();
      t.leagueMatch!.games[16].score(3, 1);
      final report = engine.tournaments([t]);
      expect(report.observations.length, 4);
      expect(report.filtered(doubleMatch: false).observations, isEmpty);
      expect(report.observations.map((o) => o.playerId).toSet().length, 4);
      expect(report.value(metric('3-Dart-Average')), isNull);
    },
  );
}
