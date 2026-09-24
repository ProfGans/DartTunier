import '../tournament_models.dart';

/// Awards automatic advances by group performance without changing qualifiers.
class GroupByeSeeding {
  const GroupByeSeeding();

  List<int?> assign({
    required List<int?> slots,
    required List<TournamentPlayer> players,
    required List<BestOfCandidate> candidates,
    required List<String> tieBreakers,
  }) {
    final result = List<int?>.from(slots);
    final byePositions = <int>[];
    for (var index = 0; index + 1 < result.length; index += 2) {
      if (result[index] != null && result[index + 1] == null) {
        byePositions.add(index);
      }
      if (result[index] == null && result[index + 1] != null) {
        byePositions.add(index + 1);
      }
    }
    if (byePositions.isEmpty) return result;
    final ranked =
        candidates
            .where((c) => players.any((p) => p.name == c.standing.player.name))
            .toList()
          ..sort((a, b) => compare(a, b, tieBreakers));
    if (ranked.length != players.length) return result;
    final winners = ranked
        .take(byePositions.length)
        .map(
          (c) =>
              players.indexWhere((p) => p.name == c.standing.player.name) + 1,
        )
        .toList();
    // Keep recipients already on a bye; only exchange ineligible recipients.
    final missing = winners
        .where((seed) => !byePositions.any((i) => result[i] == seed))
        .toList();
    for (final position in byePositions) {
      if (winners.contains(result[position])) continue;
      final seed = missing.removeAt(0);
      final from = result.indexOf(seed);
      final displaced = result[position];
      result[position] = seed;
      result[from] = displaced;
    }
    return result;
  }

  int compare(BestOfCandidate a, BestOfCandidate b, List<String> tieBreakers) {
    final place = a.place.compareTo(b.place);
    if (place != 0) return place;
    final aGames = a.standing.played == 0 ? 1 : a.standing.played;
    final bGames = b.standing.played == 0 ? 1 : b.standing.played;
    for (final rule in tieBreakers) {
      final aValue = switch (rule) {
        'points' => a.standing.points,
        'legDifference' => a.standing.legDifference,
        'legsFor' => a.standing.legsFor,
        _ => 0,
      };
      final bValue = switch (rule) {
        'points' => b.standing.points,
        'legDifference' => b.standing.legDifference,
        'legsFor' => b.standing.legsFor,
        _ => 0,
      };
      final comparison = (bValue * aGames).compareTo(aValue * bGames);
      if (comparison != 0) return comparison;
    }
    // Stable tie resolution, independent of the order of the groups.
    return a.standing.player.name.compareTo(b.standing.player.name);
  }
}
