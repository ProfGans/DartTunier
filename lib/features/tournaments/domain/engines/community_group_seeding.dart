import '../tournament_models.dart';

enum CommunityGroupSeedingMode { mixed, strengthSplit }

/// Produces a stable permutation of incoming players for community group draws.
/// Ratings may be absent for guests; those players use the supplied baseline.
class CommunityGroupSeeding {
  const CommunityGroupSeeding();

  List<int> order({
    required List<TournamentPlayer> players,
    required List<int> groupSizes,
    required Map<String, int> ratingsByProfileId,
    required CommunityGroupSeedingMode mode,
    int unratedBaseline = 1000,
  }) {
    if (groupSizes.isEmpty || groupSizes.any((size) => size < 0)) {
      throw ArgumentError.value(groupSizes, 'groupSizes');
    }
    if (groupSizes.fold<int>(0, (sum, size) => sum + size) != players.length) {
      throw ArgumentError('Gruppengrößen müssen alle Teilnehmer abdecken.');
    }
    if (mode == CommunityGroupSeedingMode.strengthSplit &&
        groupSizes.length != 2) {
      throw ArgumentError('Stärkegruppen benötigen genau zwei Gruppen.');
    }

    final ranked = List<int>.generate(players.length, (index) => index)
      ..sort((a, b) {
        final aRating = _rating(
          players[a],
          ratingsByProfileId,
          unratedBaseline,
        );
        final bRating = _rating(
          players[b],
          ratingsByProfileId,
          unratedBaseline,
        );
        final byRating = bRating.compareTo(aRating);
        return byRating != 0 ? byRating : a.compareTo(b);
      });
    final groups = List.generate(groupSizes.length, (_) => <int>[]);

    if (mode == CommunityGroupSeedingMode.strengthSplit) {
      var rank = 0;
      for (var group = 0; group < groupSizes.length; group++) {
        for (var slot = 0; slot < groupSizes[group]; slot++) {
          groups[group].add(ranked[rank++]);
        }
      }
    } else {
      var rank = 0;
      var group = 0;
      while (rank < ranked.length) {
        if (groups[group].length < groupSizes[group]) {
          groups[group].add(ranked[rank++]);
        }
        group = (group + 1) % groups.length;
      }
    }

    return [for (final group in groups) ...group];
  }

  int _rating(
    TournamentPlayer player,
    Map<String, int> ratingsByProfileId,
    int baseline,
  ) {
    if (player.isTeam) return baseline;
    return ratingsByProfileId[player.profileId] ?? baseline;
  }
}
