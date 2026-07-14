import '../data/tournament_storage.dart';
import '../domain/tournament_models.dart';

class TournamentCreationController {
  const TournamentCreationController({TournamentStorage? storage})
    : _storage = storage;

  final TournamentStorage? _storage;

  CreatedTournament createTournament({
    required String name,
    required List<TournamentPlayer> players,
    required List<TournamentStage> stages,
    required List<TournamentRunStage> runStages,
  }) {
    final tournament = CreatedTournament(
      name: name.trim().isEmpty ? 'Neues Turnier' : name.trim(),
      players: List.unmodifiable(players),
      stages: List.unmodifiable(stages),
      runStages: runStages,
    );

    (_storage ?? TournamentStorage()).saveTournament(tournament);
    return tournament;
  }
}
