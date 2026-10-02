import 'package:flutter_test/flutter_test.dart';
import 'package:dart_tournament_manager/features/league/application/league_board_runtime.dart';
import 'package:dart_tournament_manager/features/league/domain/league_match.dart';
import 'package:dart_tournament_manager/features/tournaments/domain/tournament_models.dart';
import 'package:dart_tournament_manager/features/tournaments/application/order_of_play/order_of_play_controller.dart';
import 'package:dart_tournament_manager/features/devices/application/board_display_projector.dart';
import 'package:dart_tournament_manager/features/devices/application/device_scorer_settings.dart';
import 'package:dart_tournament_manager/features/devices/application/device_result_importer.dart';

CreatedTournament fixture() => CreatedTournament(
  name: 'Liga',
  players: [],
  stages: [],
  runStages: [],
  boardCount: 2,
  leagueMatch: LeagueMatch.rhl(
    homeTeam: 'Heim',
    awayTeam: 'Gast',
    homePlayers: ['H1', 'H2', 'H3', 'H4'],
    awayPlayers: ['G1', 'G2', 'G3', 'G4'],
  ),
);
void main() {
  test('league boards prevent double booking, including double partners', () {
    final source = fixture();
    final runtime = LeagueBoardRuntime(source);
    const scheduler = OrderOfPlayController();
    expect(
      scheduler.start(runtime.tournament, 0, runtime.matches[16], 1),
      isTrue,
    );
    expect(
      scheduler.start(runtime.tournament, 0, runtime.matches[0], 2),
      isFalse,
    );
    expect(
      scheduler.start(runtime.tournament, 0, runtime.matches[17], 1),
      isFalse,
    );
    expect(
      scheduler.start(runtime.tournament, 0, runtime.matches[17], 2),
      isTrue,
    );
    runtime.writeTo(source);
    final restored = LeagueBoardRuntime(
      CreatedTournament.fromJson(source.toJson()),
    );
    expect(restored.schedule.running.length, 2);
    final display = const BoardDisplayProjector().project(
      restored.tournament,
      0,
    )[1]!;
    expect(display.state, 'running');
    expect(deviceScorerSettings(display).participants.first.members, [
      'H1',
      'H2',
    ]);
  });
  test(
    'production result importer persists league score and frees the board',
    () {
      final source = fixture();
      final runtime = LeagueBoardRuntime(source);
      const OrderOfPlayController().start(
        runtime.tournament,
        0,
        runtime.matches[0],
        1,
      );
      final display = const BoardDisplayProjector().project(
        runtime.tournament,
        0,
      )[1]!;
      final result = <String, dynamic>{
        'version': 1,
        'matchId': display.matchId,
        'legs': [3, 0],
        'sets': [0, 0],
        'statistics': {
          'schemaVersion': 1,
          'id': 'test',
          'accountId': '',
          'playedAt': DateTime.now().toIso8601String(),
          'playerIndex': 0,
          'names': ['H1', 'G1'],
          'startScores': [501, 501],
          'standard501Rules': true,
          'doubleOut': true,
          'winner': 0,
          'visits': [
            for (var leg = 0; leg < 3; leg++) ...[
              {
                'player': 0,
                'leg': leg,
                'starter': 0,
                'points': 180,
                'darts': 3,
                'remaining': 321,
                'bust': false,
                'checkoutAttempts': 0,
              },
              {
                'player': 0,
                'leg': leg,
                'starter': 0,
                'points': 180,
                'darts': 3,
                'remaining': 141,
                'bust': false,
                'checkoutAttempts': 0,
              },
              {
                'player': 0,
                'leg': leg,
                'starter': 0,
                'points': 141,
                'darts': 3,
                'remaining': 0,
                'bust': false,
                'checkoutAttempts': 1,
              },
            ],
          ],
        },
      };
      const importer = DeviceResultImporter();
      final match = importer.validate(runtime.tournament, result);
      importer.apply(
        match,
        result,
        runtime.tournament.stages.single.gameFormat,
      );
      runtime.writeTo(source);
      final copy = CreatedTournament.fromJson(source.toJson());
      expect(copy.leagueMatch!.homePoints, 1);
      expect(LeagueBoardRuntime(copy).schedule.running, isEmpty);
      expect(copy.leagueMatch!.games.first.runtime!['deviceResult'], isNotNull);
      expect(
        () => importer.validate(runtime.tournament, {
          ...result,
          'matchId': 'obsolete',
        }),
        throwsStateError,
      );
    },
  );
}
