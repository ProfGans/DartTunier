class MatchResult {
  const MatchResult({
    required this.homeLegs,
    required this.awayLegs,
    this.isAnnulled = false,
  });

  const MatchResult.annulled()
    : homeLegs = null,
      awayLegs = null,
      isAnnulled = true;

  final int? homeLegs;
  final int? awayLegs;
  final bool isAnnulled;
}
