import '../tournament_models.dart';

/// Conservative proof: never treat a possible points tie as already won.
class QualificationCertainty {
  const QualificationCertainty();

  bool isCertain({required PlayerStanding standing, required int place,
    required int fixedPlaces, required List<PlayerStanding> standings,
    required List<GroupMatch> matches, required List<String> tieBreakers}) {
    if (fixedPlaces < 1 || place > fixedPlaces) return false;
    if (matches.every((match) => match.isResolved)) return true;
    // Points can only bound the final ranking when they are the first criterion.
    if (tieBreakers.isEmpty || tieBreakers.first != 'points') return false;
    final possibleOvertakers = standings.where((other) {
      if (other.player.name == standing.player.name) return false;
      final remaining = matches.where((match) => !match.isResolved && !match.isDecider &&
        (match.homePlayer?.name == other.player.name || match.awayPlayer?.name == other.player.name)).length;
      // Equal points may still mean a better final leg difference or another
      // tie-breaker. Independent upper bounds may delay certainty, never fake it.
      return other.points + remaining * 3 >= standing.points;
    }).length;
    return possibleOvertakers < fixedPlaces;
  }
}
