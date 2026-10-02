import 'dart:convert';
import 'dart:io';
import 'package:dart_tournament_manager/features/statistics/domain/statistics_period.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_tournament_manager/features/statistics/domain/saved_scorer_match.dart';
import 'package:dart_tournament_manager/features/statistics/domain/tournament_player_statistics.dart';
import 'package:dart_tournament_manager/features/statistics/data/player_statistics_repository.dart';
import 'package:dart_tournament_manager/features/scorer/domain/scorer_statistics.dart';
import 'package:dart_tournament_manager/features/tournaments/data/tournament_storage.dart';
import 'package:dart_tournament_manager/features/tournaments/domain/tournament_models.dart';

SavedScorerMatch sample({
  String id = 'game',
  List<ScorerVisit>? visits,
  int? winner,
}) => SavedScorerMatch(
  id: id,
  accountId: 'account-a',
  playedAt: DateTime.utc(2026),
  playerIndex: 0,
  names: ['Anna', 'Bot'],
  startScores: [501, 501],
  standard501Rules: true,
  doubleOut: true,
  winner: winner,
  visits:
      visits ??
      [
        const ScorerVisit(
          player: 0,
          leg: 0,
          starter: 0,
          points: 180,
          darts: 3,
          remaining: 321,
          bust: false,
          checkoutAttempts: 0,
        ),
      ],
);

void main() {
  test(
    'offline retry uploads latest snapshot and never sends another account',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'statistics_sync_',
      );
      addTearDown(() => directory.delete(recursive: true));
      final storage = TournamentStorage(
        file: File('${directory.path}/tournaments.json'),
      );
      var user = 'account-a';
      var offline = true;
      final uploaded = <Map<String, dynamic>>[];
      final repository = PlayerStatisticsRepository(
        storage: storage,
        currentUserId: () => user,
        upload: (row) async {
          if (offline) throw const SocketException('offline');
          uploaded.add(row);
        },
        download: (_) async => [],
      );
      await repository.save(sample(winner: 0));
      await repository.synchronize(user);
      expect(
        (await storage.readPlayerStatistics(user))['game']['pending'],
        true,
      );
      await repository.save(sample(visits: [])); // Undo before reconnection.
      user = 'account-b';
      offline = false;
      await repository.synchronize('account-a');
      expect(uploaded, isEmpty);
      user = 'account-a';
      await repository.synchronize(user);
      expect(uploaded.single['payload']['winner'], isNull);
      expect(uploaded.single['payload']['visits'], isEmpty);
      expect(
        (await storage.readPlayerStatistics(user))['game']['pending'],
        false,
      );
    },
  );

  test(
    'edit during upload stays pending and stale download cannot replace it',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'statistics_race_',
      );
      addTearDown(() => directory.delete(recursive: true));
      final storage = TournamentStorage(
        file: File('${directory.path}/tournaments.json'),
      );
      late PlayerStatisticsRepository repository;
      repository = PlayerStatisticsRepository(
        storage: storage,
        currentUserId: () => 'account-a',
        upload: (_) async {
          await repository.save(sample(visits: []));
        },
        download: (_) async => [
          {'session_id': 'game', 'payload': sample(winner: 0).toJson()},
        ],
      );
      await repository.save(sample(winner: 0));
      await repository.synchronize('account-a');
      expect((await repository.load('account-a')).single.visits, isEmpty);
      expect(
        (await storage.readPlayerStatistics('account-a'))['game']['pending'],
        true,
      );
    },
  );
  test(
    'version 6 migration, restart, account separation and undo replace a session',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'profile_statistics_',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/tournaments.json');
      const original = '{"schemaVersion":6,"tournaments":[],"custom":"keep"}';
      await file.writeAsString(original);
      final storage = TournamentStorage(file: file);
      final repository = PlayerStatisticsRepository(storage: storage);
      await repository.save(sample(winner: 0));
      await repository.save(sample(winner: 0));
      final restarted = PlayerStatisticsRepository(
        storage: TournamentStorage(file: file),
      );
      expect(
        (await restarted.load('account-a')).single.statistics.scores180,
        1,
      );
      expect(await restarted.load('account-b'), isEmpty);
      await restarted.save(sample(visits: []));
      final rows = await restarted.load('account-a');
      expect(rows, hasLength(1));
      expect(rows.single.winner, isNull);
      expect(rows.single.statistics.scores180, 0);
      await restarted.synchronize('account-a');
      expect(
        (await storage.readPlayerStatistics('account-a'))['game']['pending'],
        true,
      );
      expect(jsonDecode(await file.readAsString())['schemaVersion'], 13);
      expect(jsonDecode(await file.readAsString())['custom'], 'keep');
      expect(await File('${file.path}.v6.bak').readAsString(), original);
    },
  );

  test(
    'totals use weighted averages and preserve unknown checkout attempts',
    () {
      final first = sample();
      final second = sample(
        id: 'two',
        visits: [
          const ScorerVisit(
            player: 0,
            leg: 0,
            starter: 0,
            points: 40,
            darts: 1,
            remaining: 0,
            bust: false,
            checkoutAttempts: null,
          ),
        ],
        winner: 0,
      );
      final totals = PersonalScorerTotals([
        first,
        SavedScorerMatch.fromJson(second.toJson()),
      ]);
      expect(
        totals.average,
        165,
      ); // 220 points / 4 darts * 3, not mean of means.
      expect(totals.checkoutPercent, isNull);
      expect(totals.wins, 1);
      expect(totals.completed, 1);
      expect(totals.scores180, 1);
      expect(totals.highestFinish, 40);
    },
  );

  test(
    'community group and KO results count once; corrections and annulments apply',
    () {
      const a = TournamentPlayer(
        profileId: 'guest-linked-to-a',
        name: 'Anna',
        isGenerated: false,
      );
      const b = TournamentPlayer(
        profileId: 'b',
        name: 'Ben',
        isGenerated: false,
      );
      final groupMatch = GroupMatch(
        round: 1,
        homePlayer: a,
        awayPlayer: b,
        homeLegs: 3,
        awayLegs: 1,
      );
      final koMatch = GroupMatch(
        round: 1,
        homePlayer: b,
        awayPlayer: a,
        homeLegs: 2,
        awayLegs: 3,
      );
      final annulled = GroupMatch(
        round: 2,
        homePlayer: a,
        awayPlayer: b,
        homeLegs: 3,
        awayLegs: 0,
        isAnnulled: true,
      );
      final tournament = CreatedTournament(
        id: 't',
        name: 'Community Cup',
        communityId: 'club',
        players: [a, b],
        stages: [],
        runStages: [
          GroupTournamentRunStage(
            name: 'Gruppe',
            groupPlayType: 'round_robin',
            qualificationPlan: null,
            tieBreakers: [],
            groups: [
              TournamentGroup(
                name: 'A',
                playType: 'round_robin',
                players: [a, b],
                matches: [groupMatch, annulled],
              ),
            ],
          ),
          KnockoutTournamentRunStage(
            name: 'Finale',
            rounds: [
              [koMatch],
            ],
          ),
        ],
      );
      List<TournamentPlayerStatistics> calculate() =>
          const TournamentStatisticsCalculator().calculate(
            [tournament, tournament],
            aliases: {'guest-linked-to-a': 'a'},
          );
      final row = calculate().singleWhere((r) => r.id == 'a');
      expect(row.matches, 2);
      expect(row.wins, 2);
      expect(row.legsFor, 6);
      expect(row.legsAgainst, 3);
      groupMatch.homeLegs = 0;
      groupMatch.awayLegs = 3;
      final corrected = calculate().singleWhere((r) => r.id == 'a');
      expect(corrected.wins, 1);
      expect(corrected.losses, 1);
      expect(corrected.tournaments.length, 1);
      final day = DateTime(2026, 10, 2);
      groupMatch.finishedAt = day;
      koMatch.startedAt = DateTime(2026, 10, 1);
      final dated = const TournamentStatisticsCalculator().calculate([
        CreatedTournament.fromJson(tournament.toJson()),
      ], period: StatisticsPeriod(day, day));
      expect(dated.every((row) => row.matches == 1), isTrue);
      expect(dated.length, 2);
      groupMatch.finishedAt = null;
      expect(
        const TournamentStatisticsCalculator().calculate([
          tournament,
        ], period: StatisticsPeriod(day, day)),
        isEmpty,
      );
    },
  );
}
