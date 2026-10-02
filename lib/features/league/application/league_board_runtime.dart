import '../../tournaments/domain/tournament_models.dart';
import '../../tournaments/application/order_of_play/order_of_play_controller.dart';

/// Adapts league fixtures to the existing scheduling and device-result engines.
/// Only the league document is persisted; the projection is rebuilt on load.
class LeagueBoardRuntime {
  LeagueBoardRuntime(CreatedTournament source) {
    final league = source.leagueMatch!;
    TournamentPlayer entrant(int side, List<int> indexes) {
      final names = side == 0 ? league.homePlayers : league.awayPlayers;
      final offset = side == 0 ? 0 : league.homePlayers.length;
      final people = [
        for (final i in indexes)
          if (source.players.length > offset + i &&
              source.players[offset + i].name == names[i])
            source.players[offset + i].copyWith(profileId: source.players[offset + i].profileId ?? 'league:${source.id}:$side:$i')
          else
            TournamentPlayer(name: names[i], profileId: 'league:${source.id}:$side:$i', isGenerated: false),
      ];
      return people.length == 1 ? people.single : TournamentPlayer.team(people);
    }

    matches = [
      for (var i = 0; i < league.games.length; i++)
        GroupMatch.fromJson({
          ...?league.games[i].runtime,
          'round': i + 1,
          'homePlayer': entrant(0, league.games[i].home).toJson(),
          'awayPlayer': entrant(1, league.games[i].away).toJson(),
          'homeLegs': league.games[i].homeLegs,
          'awayLegs': league.games[i].awayLegs,
        }),
    ];
    tournament = CreatedTournament(
      id: source.id,
      name: source.name,
      communityId: source.communityId,
      boardCount: source.boardCount,
      players: source.players,
      stages: const [
        TournamentStage(
          name: 'Ligaspiel',
          type: 'groups',
          gameFormat: TournamentGameFormat(bestOfLegs: 5),
        ),
      ],
      runStages: [
        GroupTournamentRunStage(
          name: 'Ligaspiel',
          groupPlayType: 'round_robin',
          qualificationPlan: null,
          tieBreakers: const [],
          groups: [
            TournamentGroup(
              name: 'Spielplan',
              playType: 'round_robin',
              players: source.players,
              matches: matches,
            ),
          ],
        ),
      ],
      completedStageIndexes: league.complete ? {0} : {},
    );
  }
  late final CreatedTournament tournament;
  late final List<GroupMatch> matches;
  BoardSchedule get schedule =>
      const OrderOfPlayController().plan(tournament, 0);
  void writeTo(CreatedTournament target) {
    for (var i = 0; i < matches.length; i++) {
      final game = target.leagueMatch!.games[i];
      game.score(matches[i].homeLegs, matches[i].awayLegs);
      game.runtime = matches[i].toJson();
    }
  }
}
