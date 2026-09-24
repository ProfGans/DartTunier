import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_tournament_manager/features/tournaments/data/tournament_storage.dart';
import 'package:dart_tournament_manager/features/tournaments/domain/tournament_models.dart';

void main() {
  test('reopening waits for the preceding result save', () async {
    final directory = await Directory.systemTemp.createTemp('result_persistence');
    addTearDown(() => directory.delete(recursive: true));
    final storage = TournamentStorage(file: File('${directory.path}/tournaments.json'));
    final match = GroupMatch(round: 1, homePlayer: TournamentPlayer.generated(1), awayPlayer: TournamentPlayer.generated(2));
    final tournament = CreatedTournament(name: 'Test', players: [], stages: [], runStages: [KnockoutTournamentRunStage(name: 'KO', rounds: [[match]])]);
    await storage.saveTournament(tournament);
    match.homeLegs = 2;
    match.awayLegs = 1;
    final save = storage.saveTournament(tournament);
    final reopened = await storage.loadTournaments();
    await save;
    expect((reopened.single.runStages.single as KnockoutTournamentRunStage).matches.single.homeLegs, 2);
  });

  test('loaded KO group list and bracket reference the same match', () {
    final match = GroupMatch(round: 1, homePlayer: TournamentPlayer.generated(1), awayPlayer: TournamentPlayer.generated(2));
    final group = TournamentGroup(name: 'A', playType: 'mini_knockout', players: [], matches: [match], knockoutRounds: [[match]]);
    final loaded = TournamentGroup.fromJson(group.toJson());
    loaded.matches.single.homeLegs = 2;
    loaded.matches.single.awayLegs = 1;
    expect(loaded.knockoutRounds.single.single.homeLegs, 2);
    final reloaded = TournamentGroup.fromJson(loaded.toJson());
    expect(reloaded.knockoutRounds.single.single.homeLegs, 2);
  });
}
