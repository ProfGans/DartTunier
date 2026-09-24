class MatchResult {
  const MatchResult({
    required this.homeLegs,
    required this.awayLegs,
    this.isAnnulled = false,
    this.homeSets,
    this.awaySets,
  });

  const MatchResult.annulled()
    : homeLegs = null,
      homeSets = null,
      awaySets = null,
      awayLegs = null,
      isAnnulled = true;

  const MatchResult.cleared()
    : homeLegs = null,
      homeSets = null,
      awaySets = null,
      awayLegs = null,
      isAnnulled = false;

  final int? homeLegs;
  final int? awayLegs;
  final int? homeSets;
  final int? awaySets;
  final bool isAnnulled;
}
