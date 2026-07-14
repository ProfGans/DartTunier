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
    tournament.activeStageIndex = activeStageIndex;
    tournament.completedStageIndexes
      ..clear()
      ..addAll(completedStageIndexes);
    await (_storage ?? TournamentStorage()).saveTournament(tournament);
  }
}
