import '../tournament_models.dart';

typedef PlacementSource = ({GroupMatch match, bool loser});
typedef PlacementInputs = ({PlacementSource home, PlacementSource away});

/// Selective classification trees for each cohort eliminated from the main KO.
/// Only paths required to determine the selected pairs of places are built.
class PlacementEngine {
  static Map<GroupMatch, PlacementInputs> plan(
    List<List<GroupMatch>> rounds, Iterable<int> places, {
    List<GroupMatch> existing = const [],
  }) {
    final selected = places.toSet();
    final stored = {for (final m in existing) m.placementKey: m};
    final edges = <GroupMatch, PlacementInputs>{};
    void branch(List<PlacementSource> inputs, int start, String key, int depth) {
      if (inputs.length < 2 || !selected.any((p) => p >= start && p < start + inputs.length)) return;
      final matches = <GroupMatch>[];
      for (var i = 0; i < inputs.length; i += 2) {
        final id = '$key/$i';
        final terminal = inputs.length == 2;
        final match = stored[id] ?? GroupMatch(
          round: 100 + depth,
          allowsBye: true,
          placementKey: id,
          placementRank: terminal ? start : null,
          label: terminal ? 'Spiel um Platz $start' : 'Plätze $start–${start + inputs.length - 1} · Spiel ${i ~/ 2 + 1}',
        );
        edges[match] = (home: inputs[i], away: inputs[i + 1]);
        matches.add(match);
      }
      if (inputs.length > 2) {
        branch(matches.map((m) => (match: m, loser: false)).toList(), start, '$key/W', depth + 1);
        branch(matches.map((m) => (match: m, loser: true)).toList(), start + inputs.length ~/ 2, '$key/L', depth + 1);
      }
    }
    for (var i = 0; i < rounds.length; i++) {
      final round = rounds[i];
      if (round.length >= 2) {
        branch(round.map((m) => (match: m, loser: true)).toList(), round.length + 1, 'R$i', 0);
      }
    }
    return edges;
  }

  static List<GroupMatch> build(List<List<GroupMatch>> rounds, Iterable<int> places) => plan(rounds, places).keys.toList();

  static Map<GroupMatch, PlacementInputs> sources(List<List<GroupMatch>> rounds, List<GroupMatch> matches) => plan(
    rounds, matches.map((m) => m.placementRank).whereType<int>(), existing: matches,
  );

  static void advance(List<List<GroupMatch>> rounds, List<GroupMatch> matches) {
    final ready = <GroupMatch, bool>{};
    for (final e in sources(rounds, matches).entries) {
      bool known(PlacementSource s) => ready[s.match] ?? s.match.isResolved;
      TournamentPlayer? player(PlacementSource s) => s.loser ? s.match.loser : s.match.winner;
      final inputsReady = known(e.value.home) && known(e.value.away);
      final home = inputsReady ? player(e.value.home) : null;
      final away = inputsReady ? player(e.value.away) : null;
      final m = e.key;
      if (m.homePlayer != home || m.awayPlayer != away) {
        m.homeLegs = m.awayLegs = m.homeSets = m.awaySets = null;
        m.isAnnulled = false;
        m.boardNumber = null;
        m.startedAt = m.finishedAt = null;
        m.startedPlayers = null;
      }
      m.homePlayer = home;
      m.awayPlayer = away;
      ready[m] = inputsReady && (m.isResolved || !m.hasPlayers);
    }
  }

  static List<TournamentPlayer> applyRanking(List<TournamentPlayer> ranking, List<GroupMatch> placements) {
    final assigned = <int, TournamentPlayer>{};
    for (final m in placements) {
      if (m.placementRank == null || !m.isResolved) continue;
      if (m.winner != null) assigned[m.placementRank! - 1] = m.winner!;
      if (m.loser != null) assigned[m.placementRank!] = m.loser!;
    }
    final remaining = ranking.where((p) => !assigned.values.contains(p)).iterator;
    return [for (var i = 0; i < ranking.length; i++)
      if (assigned.containsKey(i)) assigned[i]!
      else if (remaining.moveNext()) remaining.current];
  }
}
