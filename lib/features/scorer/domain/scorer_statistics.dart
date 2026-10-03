import 'scorer_highlight_rules.dart';

/// One completed visit. Non-finishing visits, including busts, count as three
/// darts for averages; finishes use the entered/observed number of darts.
class ScorerVisit {
  const ScorerVisit({
    required this.player,
    required this.leg,
    required this.starter,
    required this.points,
    required this.darts,
    required this.remaining,
    required this.bust,
    required this.checkoutAttempts,
  });
  final int player, leg, starter, points, darts, remaining;
  final bool bust;
  final int? checkoutAttempts;
  bool get finished => !bust && remaining == 0;
}

class ScorerPlayerStatistics {
  final Map<int, int> maxima = {}, shortLegs = {};
  int points = 0, darts = 0, visits = 0, busts = 0;
  int firstNinePoints = 0, firstNineDarts = 0;
  int scores60 = 0, scores100 = 0, scores140 = 0, scores180 = 0;
  int highestScore = 0, highestFinish = 0, tonFinishes = 0;
  int legsPlayed = 0, legsWon = 0, wonLegDarts = 0;
  int breaks = 0, holds = 0, nineDarters = 0;
  int? bestLeg;
  int checkoutAttempts = 0, unknownCheckoutVisits = 0;
  double? get average => darts == 0 ? null : points * 3 / darts;
  double? get firstNineAverage =>
      firstNineDarts == 0 ? null : firstNinePoints * 3 / firstNineDarts;
  double? get checkoutPercent =>
      unknownCheckoutVisits > 0 || checkoutAttempts == 0
      ? null
      : legsWon * 100 / checkoutAttempts;
  double? get dartsPerWonLeg => legsWon == 0 ? null : wonLegDarts / legsWon;
}

class ScorerLegSummary {
  const ScorerLegSummary({
    required this.number,
    required this.winner,
    required this.starter,
    required this.darts,
    required this.finish,
  });
  final int number, winner, starter, darts, finish;
}

class ScorerStatistics {
  ScorerStatistics._(this.players, this.legs);
  final List<ScorerPlayerStatistics> players;
  final List<ScorerLegSummary> legs;

  factory ScorerStatistics.calculate(
    List<ScorerVisit> visits, {
    required int playerCount,
    required List<int> startScores,
    required bool standard501Rules,
  }) {
    final players = List.generate(playerCount, (_) => ScorerPlayerStatistics());
    final legs = <ScorerLegSummary>[];
    final legDarts = <(int, int), int>{};
    final legVisits = <(int, int), int>{};
    for (final visit in visits) {
      final p = players[visit.player];
      final key = (visit.leg, visit.player);
      final previousVisits = legVisits[key] ?? 0;
      legVisits[key] = previousVisits + 1;
      legDarts[key] = (legDarts[key] ?? 0) + visit.darts;
      p.points += visit.points;
      p.darts += visit.darts;
      p.visits++;
      if (previousVisits < 3) {
        p.firstNinePoints += visit.points;
        p.firstNineDarts += visit.darts;
      }
      if (visit.bust) p.busts++;
      if (visit.points >= 60) p.scores60++;
      if (visit.points >= 100) p.scores100++;
      if (visit.points >= 140) p.scores140++;
      if (visit.points == 180) p.scores180++;
      if (!visit.bust && highlightMaximumScores.contains(visit.points)) {
        p.maxima.update(visit.points, (count) => count + 1, ifAbsent: () => 1);
      }
      if (visit.points > p.highestScore) p.highestScore = visit.points;
      if (visit.checkoutAttempts == null) {
        p.unknownCheckoutVisits++;
      } else {
        p.checkoutAttempts += visit.checkoutAttempts!;
      }
      if (!visit.finished) continue;
      for (final player in players) {
        player.legsPlayed++;
      }
      p.legsWon++;
      final darts = legDarts[key]!;
      if (darts > 0 && darts <= highlightShortLegDarts) {
        p.shortLegs.update(darts, (count) => count + 1, ifAbsent: () => 1);
      }
      p.wonLegDarts += darts;
      if (p.bestLeg == null || darts < p.bestLeg!) p.bestLeg = darts;
      if (visit.points > p.highestFinish) p.highestFinish = visit.points;
      if (visit.points >= 100) p.tonFinishes++;
      if (playerCount == 2) {
        if (visit.player == visit.starter) {
          p.holds++;
        } else {
          p.breaks++;
        }
      }
      if (standard501Rules && startScores[visit.player] == 501 && darts == 9) {
        p.nineDarters++;
      }
      legs.add(
        ScorerLegSummary(
          number: visit.leg + 1,
          winner: visit.player,
          starter: visit.starter,
          darts: darts,
          finish: visit.points,
        ),
      );
    }
    return ScorerStatistics._(players, legs);
  }
}
