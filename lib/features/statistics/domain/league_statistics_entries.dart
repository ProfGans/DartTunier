import '../../tournaments/domain/tournament_models.dart';

/// Roster positions identify players within a saved league match. Names alone
/// must not attach an unlinked league result to somebody's account.
class LeagueStatisticsEntry {
  const LeagueStatisticsEntry(
    this.id,
    this.name,
    this.isDouble,
    this.ownLegs,
    this.otherLegs,
  );
  final String id, name;
  final bool isDouble;
  final int ownLegs, otherLegs;
}

Iterable<LeagueStatisticsEntry> leagueStatisticsEntries(
  CreatedTournament tournament,
) sync* {
  final league = tournament.leagueMatch;
  if (league == null) return;
  for (final game in league.games) {
    if (!game.complete) continue;
    for (var side = 0; side < 2; side++) {
      final roster = side == 0 ? league.homePlayers : league.awayPlayers;
      final players = side == 0 ? game.home : game.away;
      for (final index in players.toSet()) {
        if (index < 0 || index >= roster.length) continue;
        final position = (side == 0 ? 0 : league.homePlayers.length) + index;
        final profile = position < tournament.players.length && tournament.players[position].name == roster[index]
            ? tournament.players[position].profileId : null;
        yield LeagueStatisticsEntry(
          profile ?? 'league:${tournament.id}:$side:$index',
          roster[index],
          game.isDouble,
          side == 0 ? game.homeLegs! : game.awayLegs!,
          side == 0 ? game.awayLegs! : game.homeLegs!,
        );
      }
    }
  }
}
