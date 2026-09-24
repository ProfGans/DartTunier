/// Counts played matches, excluding automatic advances through byes.
class PlanningMatchBreakdown {
  PlanningMatchBreakdown({
    required List<int> groupSizes,
    required this.qualifiersPerGroup,
  }) : groupSizes = List.unmodifiable(groupSizes);

  final List<int> groupSizes;
  final int qualifiersPerGroup;
  List<int> get groupMatches => [
    for (final size in groupSizes) size * (size - 1) ~/ 2,
  ];
  int get groupTotal => groupMatches.fold(0, (sum, count) => sum + count);
  int get knockoutParticipants => groupSizes.length == 1
      ? 0
      : groupSizes.fold(
          0,
          (sum, size) =>
              sum + (size < qualifiersPerGroup ? size : qualifiersPerGroup),
        );
  int get knockoutMatches =>
      knockoutParticipants < 2 ? 0 : knockoutParticipants - 1;
  int get byes {
    if (knockoutParticipants < 2) return 0;
    var slots = 1;
    while (slots < knockoutParticipants) {
      slots *= 2;
    }
    return slots - knockoutParticipants;
  }

  int get total => groupTotal + knockoutMatches;
}
