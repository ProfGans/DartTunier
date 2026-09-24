import 'tournament_models.dart';

/// Odd best-of distances increase by two. An even group distance moves to
/// the next odd distance for knockout (e.g. Bo4 -> Bo5).
bool isPlanningFormatProgressionAllowed(
  TournamentGameFormat previous,
  TournamentGameFormat next,
) {
  final maxLegs = previous.bestOfLegs + (previous.bestOfLegs.isEven ? 1 : 2);
  return next.bestOfLegs >= previous.bestOfLegs &&
      next.bestOfLegs <= maxLegs &&
      next.bestOfSets >= previous.bestOfSets &&
      next.bestOfSets <= previous.bestOfSets + 2;
}
