import '../data/tournament_storage.dart';
import '../domain/tournament_models.dart';

class TournamentRunController {
  const TournamentRunController({TournamentStorage? storage})
    : _storage = storage;

  final TournamentStorage? _storage;

  Future<void> saveProgress({
    required CreatedTournament tournament,
    required int activeStageIndex,
    required Set<int> completedStageIndexes,
  }) async {
    final wasComplete = _isComplete(tournament);
    tournament.activeStageIndex = activeStageIndex;
    tournament.completedStageIndexes
      ..clear()
      ..addAll(completedStageIndexes);
    final storage = _storage ?? TournamentStorage();
    await storage.saveTournament(tournament);
    if (!wasComplete && _isComplete(tournament) && tournament.communityId != null) {
      await storage.synchronize(tournamentId: tournament.id);
    }
  }

  bool _isComplete(CreatedTournament tournament) =>
      tournament.runStages.isNotEmpty &&
      List.generate(tournament.runStages.length, (index) => index)
          .every(tournament.completedStageIndexes.contains);
}
