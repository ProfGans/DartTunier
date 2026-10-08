import '../tournament_models.dart';

/// Fixed, balanced opponent schedule. Unlike Swiss, results do not affect draws.
class LimitedRoundRobinEngine {
  static List<GroupMatch> build(
    List<TournamentPlayer> players, {
    required int maxGamesPerPlayer,
    int repeatCount = 1,
  }) {
    if (maxGamesPerPlayer < 1) {
      throw ArgumentError.value(maxGamesPerPlayer, 'maxGamesPerPlayer');
    }
    final n = players.length;
    if (n < 2) return [];
    final capacity = (n - 1) * (repeatCount < 1 ? 1 : repeatCount);
    var remaining = maxGamesPerPlayer < capacity ? maxGamesPerPlayer : capacity;
    final result = <GroupMatch>[];
    var offset = 0;
    while (remaining > 0) {
      final degree = remaining < n - 1 ? remaining : n - 1;
      final pairs = <(int, int)>[];
      for (var distance = 1; distance <= degree ~/ 2; distance++) {
        for (var i = 0; i < n; i++) {
          pairs.add((i, (i + distance) % n));
        }
      }
      if (degree.isOdd) {
        if (n.isEven) {
          for (var i = 0; i < n ~/ 2; i++) {
            pairs.add((i, i + n ~/ 2));
          }
        } else {
          final step = n ~/ 2;
          for (var i = 0; i < n - 1; i += 2) {
            pairs.add(((i * step) % n, ((i + 1) * step) % n));
          }
        }
      }
      final occupied = <Set<int>>[];
      for (final pair in pairs) {
        var round = 0;
        while (round < occupied.length &&
            (occupied[round].contains(pair.$1) ||
                occupied[round].contains(pair.$2))) {
          round++;
        }
        if (round == occupied.length) occupied.add({});
        occupied[round].addAll([pair.$1, pair.$2]);
        result.add(
          GroupMatch(
            homePlayer: players[pair.$1],
            awayPlayer: players[pair.$2],
            round: offset + round + 1,
          ),
        );
      }
      offset += occupied.length;
      remaining -= degree;
    }
    result.sort((a, b) => a.round.compareTo(b.round));
    return result;
  }
}
