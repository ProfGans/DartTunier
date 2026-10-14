import '../../rankings/domain/local_ranking.dart';
import '../../rankings/application/local_ranking_elo_service.dart';
import '../../tournaments/data/app_database.dart';
import '../../tournaments/data/tournament_storage.dart';
import '../../tournaments/domain/tournament_models.dart';
import 'best_performance.dart';

class LocalPlayerStatistics {
  const LocalPlayerStatistics({
    required this.tournaments,
    required this.matches,
    required this.wins,
    required this.losses,
    required this.draws,
    required this.legsWon,
    required this.legsLost,
    required this.setsWon,
    required this.setsLost,
    required this.bestPerformances,
    required this.expectedWinChance,
  });
  final int tournaments, matches, wins, losses, draws;
  final int legsWon, legsLost, setsWon, setsLost;
  final List<BestPerformance> bestPerformances;
  final double? expectedWinChance;
  double get matchWinRate => matches == 0 ? 0 : wins * 100 / matches;
  double get legWinRate => legsWon + legsLost == 0 ? 0 : legsWon * 100 / (legsWon + legsLost);
  double get setWinRate => setsWon + setsLost == 0 ? 0 : setsWon * 100 / (setsWon + setsLost);
}

class LocalStatisticsService {
  const LocalStatisticsService({this.database, this.storage});
  final LocalAppDatabase? database;
  final TournamentStorage? storage;

  Future<LocalPlayerStatistics> forPlayers(Set<String> ids) async {
    final database = this.database ?? LocalAppDatabase();
    final localProfiles = await database.loadPlayerProfiles();
    final profileByName = <String, String>{
      for (final profile in localProfiles)
        profile.displayName.trim().toLowerCase(): profile.id,
    };
    final tournaments = await (storage ?? TournamentStorage()).loadTournaments();
    final playedTournamentIds = <String>{};
    var matches = 0, wins = 0, losses = 0, draws = 0;
    var legsWon = 0, legsLost = 0, setsWon = 0, setsLost = 0;
    final performances = <BestPerformance>[];
    for (final tournament in tournaments) {
      if (tournament.players.any((p) => p.profileId != null && ids.contains(p.profileId))) {
        playedTournamentIds.add(tournament.id);
      }
      for (final match in _matches(tournament)) {
        if (!match.hasResult || match.withdrawalIgnored) continue;
        final home = match.homePlayer?.profileId;
        final away = match.awayPlayer?.profileId;
        final homeIn = home != null && ids.contains(home);
        final awayIn = away != null && ids.contains(away);
        if (homeIn == awayIn) continue;
        matches++;
        final isHome = homeIn;
        if (match.homeScore == match.awayScore) {
          draws++;
        } else if ((isHome && match.homeScore! > match.awayScore!) ||
            (!isHome && match.awayScore! > match.homeScore!)) {
          wins++;
        } else {
          losses++;
        }
        legsWon += isHome ? match.homeLegs ?? 0 : match.awayLegs ?? 0;
        legsLost += isHome ? match.awayLegs ?? 0 : match.homeLegs ?? 0;
        setsWon += isHome ? match.homeSets ?? 0 : match.awaySets ?? 0;
        setsLost += isHome ? match.awaySets ?? 0 : match.homeSets ?? 0;
        performances.addAll(match.bestPerformances.where((p) =>
            (p.playerProfileId != null && ids.contains(p.playerProfileId)) ||
            (p.playerProfileId == null && (isHome ? match.homePlayer?.name : match.awayPlayer?.name) == p.playerName)));
      }
      final archive = tournament.importedArchive;
      if (archive != null) {
        final profileByChallongeId = <String, String>{
          for (final participant in archive.participants)
            if (participant['profileId'] is String)
              '${participant['id']}': participant['profileId'] as String,
          for (final participant in archive.participants)
            if (participant['profileId'] is String)
              for (final alias in participant['groupPlayerIds'] as List? ?? const [])
                '$alias': participant['profileId'] as String,
        };
        final nameByChallongeId = <String, String>{
          for (final participant in archive.participants)
            '${participant['id']}': '${participant['name'] ?? ''}',
          for (final participant in archive.participants)
            for (final alias in participant['groupPlayerIds'] as List? ?? const [])
              '$alias': '${participant['name'] ?? ''}',
        };
        for (final importedMatch in archive.matches) {
          final rawPerformances = importedMatch['bestPerformances'] as List? ?? const [];
          final challongeIds = ['${importedMatch['player1_id']}', '${importedMatch['player2_id']}'];
          for (final raw in rawPerformances.whereType<Map>()) {
            final performance = BestPerformance.fromJson(Map<String, dynamic>.from(raw));
            final matchingProfileIds = challongeIds
                .where((id) => nameByChallongeId[id] == performance.playerName)
                .map((id) => profileByChallongeId[id])
                .whereType<String>()
                .toList();
            final profileId = performance.playerProfileId ??
                (matchingProfileIds.isEmpty
                    ? profileByName[performance.playerName.trim().toLowerCase()]
                    : matchingProfileIds.first);
            if (profileId != null && ids.contains(profileId)) performances.add(performance);
          }
        }
      }
    }
    var expectedTotal = 0.0;
    var expectedCount = 0;
    final rankingIds = <String>{};
    for (final id in ids) {
      for (final ranking in await database.loadRankingsForPlayer(id)) {
        if (ranking.type == RankingType.elo && rankingIds.add(ranking.id)) {
          final snapshot = await LocalRankingEloService(database: database).calculate(ranking);
          for (final item in snapshot.history[id] ?? const []) {
            expectedTotal += item.expectedScore;
            expectedCount++;
          }
        }
      }
    }
    return LocalPlayerStatistics(
      tournaments: playedTournamentIds.length,
      matches: matches,
      wins: wins,
      losses: losses,
      draws: draws,
      legsWon: legsWon,
      legsLost: legsLost,
      setsWon: setsWon,
      setsLost: setsLost,
      bestPerformances: performances,
      expectedWinChance: expectedCount == 0 ? null : expectedTotal * 100 / expectedCount,
    );
  }

  Future<List<LocalRanking>> rankingsFor(Set<String> playerIds) async {
    if (playerIds.isEmpty) return const [];
    return (database ?? LocalAppDatabase()).loadRankingsForPlayer(playerIds.first);
  }

  Iterable<GroupMatch> _matches(CreatedTournament tournament) sync* {
    for (final stage in tournament.runStages) {
      if (stage is KnockoutTournamentRunStage) {
        yield* stage.matches;
        yield* stage.placementMatches;
      } else if (stage is GroupTournamentRunStage) {
        for (final group in stage.groups) {
          yield* group.matches;
          yield* group.knockoutRounds.expand((round) => round);
          yield* group.placementMatches;
        }
      }
    }
  }
}
