import 'tournament_models.dart';

/// Aggregate legs must be attainable from the reported set wins.
bool isValidSetResult(
  TournamentGameFormat format, {
  required int homeSets,
  required int awaySets,
  required int homeLegs,
  required int awayLegs,
}) {
  final setsToWin = format.bestOfSets ~/ 2 + 1;
  final legsToWin = format.bestOfLegs ~/ 2 + 1;
  if (homeSets < 0 ||
      awaySets < 0 ||
      !((homeSets == setsToWin && awaySets < setsToWin) ||
          (awaySets == setsToWin && homeSets < setsToWin))) {
    return false;
  }
  bool attainable(int legs, int won, int lost) =>
      legs >= won * legsToWin &&
      legs <= won * legsToWin + lost * (legsToWin - 1);
  return attainable(homeLegs, homeSets, awaySets) &&
      attainable(awayLegs, awaySets, homeSets);
}
