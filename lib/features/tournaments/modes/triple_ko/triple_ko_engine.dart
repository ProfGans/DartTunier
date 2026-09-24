import '../../domain/tournament_models.dart';

const tripleFinalLabel = 'Triple-KO Finalrunde';
String tripleRoundLabel(int losses, int round) =>
    '${losses == 1 ? '1 Niederlage' : '$losses Niederlagen'} Runde $round';

typedef TripleSource = ({GroupMatch match, bool loser});
typedef TripleSources = ({TripleSource? first, TripleSource? second});

/// Each loss bracket consumes every round of the preceding bracket.
/// Progression and the graphical bracket share these source edges.
class TripleKoEngine {
  static List<List<GroupMatch>> build(List<GroupMatch> first, {int lossLimit = 3}) =>
      _plan(first, lossLimit).rounds;

  static _TriplePlan _plan(List<GroupMatch> first, int lossLimit) {
    if (lossLimit < 2 || lossLimit > 10) throw ArgumentError.value(lossLimit, 'lossLimit');
    final rounds = <List<GroupMatch>>[first];
    final edges = <GroupMatch, TripleSources>{};
    List<GroupMatch> addRound(List<TripleSource> pool, int losses, int number) {
      final matches = <GroupMatch>[];
      for (var i = 0; i < pool.length; i += 2) {
        final match = GroupMatch(
          round: rounds.length + 1,
          label: tripleRoundLabel(losses, number),
          allowsBye: true,
        );
        edges[match] = (
          first: pool[i],
          second: i + 1 < pool.length ? pool[i + 1] : null,
        );
        matches.add(match);
      }
      rounds.add(matches);
      return matches;
    }

    TripleSource winner(GroupMatch m) => (match: m, loser: false);
    TripleSource loser(GroupMatch m) => (match: m, loser: true);
    var upper = <List<GroupMatch>>[first];
    while (upper.last.length > 1) {
      upper.add(addRound(upper.last.map(winner).toList(), 0, upper.length + 1));
    }
    final champions = <TripleSource>[winner(upper.last.single)];
    for (var losses = 1; losses < lossLimit; losses++) {
      final lower = <List<GroupMatch>>[];
      var survivors = <TripleSource>[];
      for (final incoming in upper) {
        final next = addRound(
          [...survivors, ...incoming.map(loser)],
          losses,
          lower.length + 1,
        );
        lower.add(next);
        survivors = next.map(winner).toList();
      }
      while (survivors.length > 1) {
        final next = addRound(survivors, losses, lower.length + 1);
        lower.add(next);
        survivors = next.map(winner).toList();
      }
      champions.add(survivors.single);
      upper = lower;
    }
    rounds.add([GroupMatch(round: rounds.length + 1, label: tripleFinalLabel)]);
    return _TriplePlan(rounds, edges, champions);
  }

  static Map<GroupMatch, TripleSources> advance(
    List<List<GroupMatch>> rounds, {
    bool update = true,
    int? lossLimit,
    bool finalEndsTournament = false,
  }) {
    if (rounds.isEmpty || rounds.first.isEmpty) return {};
    final limit = lossLimit ?? inferredLossLimit(rounds);
    final plan = _plan(rounds.first, limit);
    final baseCount = plan.rounds.length - 1;
    final old = rounds.expand((r) => r).toList();
    final aligned = <List<GroupMatch>>[rounds.first];
    for (var r = 1; r < baseCount; r++) {
      final expected = plan.rounds[r];
      final candidates = old
          .where((m) => m.label == expected.first.label)
          .toList();
      aligned.add(
        candidates.length == expected.length
            ? [
                for (var i = 0; i < candidates.length; i++)
                  candidates[i].round == expected[i].round
                      ? candidates[i]
                      : GroupMatch.fromJson({
                          ...candidates[i].toJson(),
                          'round': expected[i].round,
                        }),
              ]
            : expected,
      );
    }
    final finals = old.where((m) => m.label == tripleFinalLabel).toList();
    final mapping = <GroupMatch, GroupMatch>{};
    for (var r = 0; r < baseCount; r++) {
      for (var i = 0; i < plan.rounds[r].length; i++) {
        mapping[plan.rounds[r][i]] = aligned[r][i];
      }
    }
    TripleSource? mapSource(TripleSource? s) =>
        s == null ? null : (match: mapping[s.match]!, loser: s.loser);
    final edges = <GroupMatch, TripleSources>{
      for (final e in plan.edges.entries)
        mapping[e.key]!: (
          first: mapSource(e.value.first),
          second: mapSource(e.value.second),
        ),
    };
    final ready = <GroupMatch, bool>{
      for (final m in rounds.first) m: m.isResolved || !m.hasPlayers,
    };
    bool known(TripleSource? s) => s == null || ready[s.match] == true;
    TournamentPlayer? player(TripleSource? s) => s == null
        ? null
        : s.loser
        ? s.match.loser
        : s.match.winner;
    for (final round in aligned.skip(1)) {
      for (final m in round) {
        final e = edges[m]!;
        final inputsReady = known(e.first) && known(e.second);
        if (update) {
          _assign(
            m,
            inputsReady ? player(e.first) : null,
            inputsReady ? player(e.second) : null,
          );
        }
        ready[m] = inputsReady && (m.isResolved || !m.hasPlayers);
      }
    }
    final champions = plan.champions.map((s) => mapSource(s)!).toList();
    final losses = <String, int>{};
    for (final m in aligned.expand((r) => r)) {
      if (m.loser != null) {
        losses.update(m.loser!.name, (n) => n + 1, ifAbsent: () => 1);
      }
    }
    final pool = <TournamentPlayer>[];
    final origins = <String, TripleSource>{};
    if (champions.every(known)) {
      for (final s in champions) {
        final p = player(s);
        if (p != null) {
          pool.add(p);
          origins[p.name] = s;
        }
      }
    }
    var index = 0;
    while (pool.length > 1 || index == 0) {
      final m = index < finals.length
          ? finals[index]
          : GroupMatch(round: baseCount + index + 1, label: tripleFinalLabel);
      pool.sort((a, b) => (losses[b.name] ?? 0).compareTo(losses[a.name] ?? 0));
      final home = pool.length > 1 ? pool[0] : null;
      final away = pool.length > 1 ? pool[1] : null;
      edges[m] = (first: origins[home?.name], second: origins[away?.name]);
      if (update) _assign(m, home, away);
      aligned.add([m]);
      index++;
      if (!m.hasResult || m.winner == null) break;
      final loser = m.loser!;
      losses.update(loser.name, (n) => n + 1, ifAbsent: () => 1);
      origins[m.winner!.name] = (match: m, loser: false);
      origins[loser.name] = (match: m, loser: true);
      if (losses[loser.name]! >= limit || (finalEndsTournament && pool.length == 2)) pool.remove(loser);
    }
    if (update) {
      rounds
        ..clear()
        ..addAll(aligned);
    }
    return edges;
  }

  static int inferredLossLimit(List<List<GroupMatch>> rounds) {
    var limit = 3;
    for (final m in rounds.expand((r) => r)) {
      final count = int.tryParse((m.label ?? '').split(' ').first);
      if (count != null && count + 1 > limit) limit = count + 1;
    }
    return limit;
  }

  static void _assign(
    GroupMatch m,
    TournamentPlayer? home,
    TournamentPlayer? away,
  ) {
    if (m.homePlayer?.name != home?.name || m.awayPlayer?.name != away?.name) {
      m.homeLegs = null;
      m.homeSets = null;
      m.awaySets = null;
      m.awayLegs = null;
      m.isAnnulled = false;
      m.boardNumber = null;
      m.startedAt = null;
      m.finishedAt = null;
      m.startedPlayers = null;
    }
    m.homePlayer = home;
    m.awayPlayer = away;
  }
}

class _TriplePlan {
  _TriplePlan(this.rounds, this.edges, this.champions);
  final List<List<GroupMatch>> rounds;
  final Map<GroupMatch, TripleSources> edges;
  final List<TripleSource> champions;
}
