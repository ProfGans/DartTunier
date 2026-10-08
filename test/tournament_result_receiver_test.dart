import 'package:flutter_test/flutter_test.dart';
import 'package:dart_tournament_manager/features/tournaments/application/tournament_result_receiver.dart';
import 'package:dart_tournament_manager/features/tournaments/application/tournament_match_assignment.dart';
import 'package:dart_tournament_manager/features/tournaments/application/order_of_play/order_of_play_controller.dart';
import 'package:dart_tournament_manager/features/tournaments/domain/tournament_models.dart';
import 'package:dart_tournament_manager/tournament_workspace.dart'
    show ProductionTournamentRuntime;

void main() {
  test(
    'external results advance Swiss through the production round barrier',
    () async {
      final players = List.generate(
        4,
        (i) => TournamentPlayer.generated(i + 1),
      );
      const config = TournamentStage(
        name: 'Swiss',
        type: 'groups',
        groupCount: 1,
        groupSizes: [4],
        groupPlayType: 'swiss',
        groupPlayTypes: ['swiss'],
        groupRoundRobinRepeats: [2],
        qualifiedParticipantCount: 1,
      );
      final cup = CreatedTournament(
        name: 'Swiss',
        players: players,
        stages: [config],
        runStages: [],
        boardCount: 2,
      );
      final runtime = ProductionTournamentRuntime(cup);
      final stage = runtime.build(config, players) as GroupTournamentRunStage;
      cup.runStages.add(stage);
      runtime.activate(0);
      final port = TournamentResultReceiver(
        tournament: cup,
        authorize: () async {},
        save: () async {},
        advance: () async {
          runtime.advance();
        },
      );
      const controller = OrderOfPlayController();
      final firstRound = stage.groups.single.matches
          .where((m) => m.round == 1)
          .toList();
      for (var i = 0; i < firstRound.length; i++) {
        expect(controller.start(cup, 0, firstRound[i], 1), true);
        final entry = controller
            .entries(cup)
            .singleWhere((e) => identical(e.match, firstRound[i]));
        await port.submit({
          'version': 1,
          'matchId': TournamentMatchAssignment.id(cup, entry),
          'legs': [2, 0],
          'sets': [0, 0],
        });
        expect(
          stage.groups.single.matches
              .where((m) => m.round == 2)
              .every((m) => m.hasPlayers),
          i == firstRound.length - 1,
        );
      }
    },
  );
  late CreatedTournament tournament;
  late GroupMatch match;
  late Map<String, dynamic> result;
  late int saves, advances;
  late TournamentResultReceiver receiver;
  void setup({TournamentGameFormat format = const TournamentGameFormat()}) {
    final players = List.generate(2, (i) => TournamentPlayer.generated(i + 1));
    match = GroupMatch(
      round: 1,
      homePlayer: players[0],
      awayPlayer: players[1],
    );
    tournament = CreatedTournament(
      name: 'Test',
      players: players,
      stages: [
        TournamentStage(
          name: 'KO',
          type: 'single_knockout',
          gameFormat: format,
        ),
      ],
      runStages: [
        KnockoutTournamentRunStage(
          name: 'KO',
          rounds: [
            [match],
          ],
        ),
      ],
    );
    const controller = OrderOfPlayController();
    controller.start(tournament, 0, match, 1);
    result = {
      'version': 1,
      'matchId': TournamentMatchAssignment.id(
        tournament,
        controller.entries(tournament).single,
      ),
      'source': 'external-test',
      'legs': [2, 1],
      'sets': [0, 0],
    };
    saves = 0;
    advances = 0;
    receiver = TournamentResultReceiver(
      tournament: tournament,
      authorize: () async {},
      save: () async {
        saves++;
      },
      advance: () async {
        advances++;
      },
    );
  }

  setUp(setup);
  test(
    'accepts result without scorer statistics; retry survives reload and stage completion',
    () async {
      expect(await receiver.submit(result), TournamentResultReceipt.accepted);
      expect(match.scoreLabel, '2:1');
      expect(saves, 2);
      expect(advances, 1);
      expect(match.deviceResult!['statistics'], isNull);
      final restored = CreatedTournament.fromJson(tournament.toJson())
        ..completedStageIndexes.add(0);
      final resumed = TournamentResultReceiver(
        tournament: restored,
        authorize: () async {},
        save: () async {},
        advance: () async {},
      );
      expect(
        await resumed.submit(result),
        TournamentResultReceipt.alreadyAccepted,
      );
      await expectLater(
        resumed.submit({
          ...result,
          'legs': [2, 0],
        }),
        throwsStateError,
      );
    },
  );
  test(
    'rejects stale assignment, invalid version and incomplete score',
    () async {
      await expectLater(
        receiver.submit({...result, 'matchId': 'other'}),
        throwsStateError,
      );
      await expectLater(
        receiver.submit({...result, 'version': 99}),
        throwsFormatException,
      );
      await expectLater(
        receiver.submit({
          ...result,
          'legs': [1, 0],
        }),
        throwsFormatException,
      );
      await expectLater(
        receiver.submit({
          ...result,
          'legs': [2.0, 0],
        }),
        throwsFormatException,
      );
      expect(match.hasResult, false);
      expect(saves, 0);
    },
  );
  test('save failure rolls result back and permits retry', () async {
    var fail = true;
    receiver = TournamentResultReceiver(
      tournament: tournament,
      authorize: () async {},
      save: () async {
        if (fail) throw StateError('disk');
      },
      advance: () async {
        advances++;
      },
    );
    await expectLater(receiver.submit(result), throwsStateError);
    expect(match.hasResult, false);
    expect(match.deviceResult, isNull);
    expect(match.finishedAt, isNull);
    expect(advances, 0);
    fail = false;
    expect(await receiver.submit(result), TournamentResultReceipt.accepted);
  });
  test('retry resumes advancement after result was already saved', () async {
    var failAdvance = true;
    receiver = TournamentResultReceiver(
      tournament: tournament,
      authorize: () async {},
      save: () async {
        saves++;
      },
      advance: () async {
        if (failAdvance) throw StateError('interrupted');
      },
    );
    await expectLater(receiver.submit(result), throwsStateError);
    expect(match.hasResult, true);
    expect(saves, 1);
    failAdvance = false;
    expect(
      await receiver.submit(result),
      TournamentResultReceipt.alreadyAccepted,
    );
    expect(saves, 2);
  });
  test(
    'authorization is required and concurrent duplicates are serialized',
    () async {
      receiver = TournamentResultReceiver(
        tournament: tournament,
        authorize: () async {
          throw StateError('denied');
        },
        save: () async {},
        advance: () async {},
      );
      await expectLater(receiver.submit(result), throwsStateError);
      expect(match.hasResult, false);
      setup();
      expect(
        await Future.wait([receiver.submit(result), receiver.submit(result)]),
        [
          TournamentResultReceipt.accepted,
          TournamentResultReceipt.alreadyAccepted,
        ],
      );
    },
  );
  test('set scores require matching aggregate legs', () async {
    setup(format: const TournamentGameFormat(bestOfSets: 3, bestOfLegs: 3));
    await expectLater(
      receiver.submit({
        ...result,
        'legs': [2, 1],
        'sets': [2, 0],
      }),
      throwsFormatException,
    );
    expect(
      await receiver.submit({
        ...result,
        'legs': [4, 1],
        'sets': [2, 0],
      }),
      TournamentResultReceipt.accepted,
    );
  });
}
