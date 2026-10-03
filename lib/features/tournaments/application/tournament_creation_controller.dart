import '../data/tournament_storage.dart';
import '../domain/tournament_models.dart';

class TournamentCreationController {
  const TournamentCreationController({TournamentStorage? storage})
    : _storage = storage;

  final TournamentStorage? _storage;

  CreatedTournament createTournament({
    int boardCount = 1,
    required String name,
    required List<TournamentPlayer> players,
    required List<TournamentStage> stages,
    required List<TournamentRunStage> runStages,
  }) {
    final tournament = _buildTournament(
      boardCount: boardCount,
      name: name,
      players: players,
      stages: stages,
      runStages: runStages,
    );
    (_storage ?? TournamentStorage()).saveTournament(tournament);
    return tournament;
  }

  Future<CreatedTournament> createCommunityTournament({
    int boardCount = 1,
    required String name,
    required List<TournamentPlayer> players,
    required List<TournamentStage> stages,
    required List<TournamentRunStage> runStages,
    required String communityId,
    bool countsForRanking = true,
    List<String> communityRankingIds = const ['default'],
  }) async {
    final tournament = _buildTournament(
      name: name,
      players: players,
      stages: stages,
      runStages: runStages,
      communityId: communityId,
      countsForRanking: countsForRanking,
      communityRankingIds: communityRankingIds,
      boardCount: boardCount,
    );
    await (_storage ?? TournamentStorage()).saveTournament(tournament);
    return tournament;
  }

  CreatedTournament _buildTournament({
    int boardCount = 1,
    required String name,
    required List<TournamentPlayer> players,
    required List<TournamentStage> stages,
    required List<TournamentRunStage> runStages,
    String? communityId,
    bool countsForRanking = true,
    List<String> communityRankingIds = const ['default'],
  }) {
    return CreatedTournament(
      boardCount: boardCount.clamp(1, 64),
      name: name.trim().isEmpty ? 'Neues Turnier' : name.trim(),
      players: List.unmodifiable(players),
      stages: List.unmodifiable(stages),
      runStages: runStages,
      communityId: communityId,
      countsForRanking: countsForRanking,
      communityRankingIds: List.unmodifiable(communityRankingIds),
    );
  }
}
