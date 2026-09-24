part of '../../../tournament_workspace.dart';

/// Transitional bridge to the production methods still owned by the workspace.
/// No widget is mounted, no UI callbacks, storage or account operations run.
/// Remove this bridge when those methods become an independent runtime library.
class ProductionTournamentRuntime {
  ProductionTournamentRuntime(CreatedTournament tournament)
      : _state = _SimulationRunState(tournament);
  final _SimulationRunState _state;
  TournamentRunStage build(TournamentStage stage, List<TournamentPlayer> players) =>
      _state._buildRunStageFromPlayers(stage, players);
  void activate(int index) { _state._activeStageIndex = index; }
  void advance() {
    _state._advanceKnockoutWinners();
    _state._ensureGroupDeciders();
  }
  bool hasOpen(TournamentRunStage stage) => _state._stageHasOpenMatches(stage);
  List<TournamentPlayer> qualifiers(TournamentRunStage stage) => _state._advancingPlayersFromStage(stage);
  List<PlayerStanding> standings(TournamentGroup group, List<String> rules) => _state._standingsFor(group, rules);
  List<GroupMatch> matches(TournamentRunStage stage) => _state._matchesForStage(stage);
}

class _SimulationRunState extends _TournamentRunPageState {
  _SimulationRunState(CreatedTournament tournament) : _simulationWidget = TournamentRunPage(tournament: tournament);
  final TournamentRunPage _simulationWidget;
  @override
  TournamentRunPage get widget => _simulationWidget;
}
