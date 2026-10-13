import 'package:flutter_test/flutter_test.dart';
import 'package:dart_tournament_manager/features/league/application/league_duration_estimator.dart';
import 'package:dart_tournament_manager/features/league/domain/league_match.dart';
import 'package:dart_tournament_manager/features/tournaments/domain/tournament_planning_parameters.dart';

void main() {
  final home = [for (var i = 1; i <= 7; i++) 'Heim $i'];
  final away = [for (var i = 1; i <= 7; i++) 'Gast $i'];

  test('adjusted schedule spreads singles and limits doubles to unique pairs', () {
    final league = LeagueMatch.adjusted(
      homeTeam: 'Heim',
      awayTeam: 'Gast',
      homePlayers: home,
      awayPlayers: away,
      singlesPerPlayer: 2,
      doublesCount: 3,
    );

    expect(league.games, hasLength(17));
    expect(league.games.where((game) => game.isDouble), hasLength(3));
    for (var player = 0; player < 7; player++) {
      expect(
        league.games.where((game) => !game.isDouble && game.home.single == player),
        hasLength(2),
      );
      expect(
        league.games.where((game) => !game.isDouble && game.away.single == player),
        hasLength(2),
      );
      expect(
        league.games.where((game) => game.isDouble && game.home.contains(player)),
        hasLength(1),
      );
    }
    final restored = LeagueMatch.fromJson(league.toJson());
    expect(restored.variant, LeagueMatchVariant.adjusted);
    expect(restored.games, hasLength(17));
    expect(restored.singlesPerPlayer, 2);
    expect(restored.doublesCount, 3);
  });

  test('cannot schedule more doubles than disjoint player pairs', () {
    expect(
      () => LeagueMatch.adjusted(
        homeTeam: 'Heim',
        awayTeam: 'Gast',
        homePlayers: home,
        awayPlayers: away,
        singlesPerPlayer: 2,
        doublesCount: 4,
      ),
      throwsFormatException,
    );
  });

  test('duration estimate uses the league board schedule and BO5 settings', () {
    final league = LeagueMatch.adjusted(
      homeTeam: 'Heim',
      awayTeam: 'Gast',
      homePlayers: home,
      awayPlayers: away,
      singlesPerPlayer: 2,
      doublesCount: 3,
    );
    const estimator = LeagueDurationEstimator();
    final oneBoard = estimator.estimate(
      league: league,
      boards: 1,
      parameters: const TournamentPlanningParameters(),
    );
    final threeBoards = estimator.estimate(
      league: league,
      boards: 3,
      parameters: const TournamentPlanningParameters(),
    );
    expect(oneBoard.matches, 17);
    expect(oneBoard.minutes, greaterThan(0));
    expect(threeBoards.minutes, lessThanOrEqualTo(oneBoard.minutes));
  });
}
