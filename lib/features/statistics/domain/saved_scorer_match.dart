import '../../scorer/domain/scorer_statistics.dart';

/// Stable session identity makes repeated saves and undo replace one record.
class SavedScorerMatch {
  const SavedScorerMatch({
    required this.id,
    required this.accountId,
    required this.playedAt,
    required this.playerIndex,
    required this.names,
    required this.startScores,
    required this.standard501Rules,
    required this.doubleOut,
    required this.visits,
    this.winner,
    this.isDraw = false,
    this.pendingDarts = 0,
  });

  final String id, accountId;
  final DateTime playedAt;
  final int playerIndex;
  final List<String> names;
  final List<int> startScores;
  final bool standard501Rules, doubleOut;
  final List<ScorerVisit> visits;
  final int? winner;
  final bool isDraw;

  /// Individually entered darts in the owner's unfinished visit.
  final int pendingDarts;
  int get thrownDarts =>
      pendingDarts +
      visits
          .where((v) => v.player == playerIndex)
          .fold<int>(0, (sum, v) => sum + (v.thrownDarts ?? v.darts));
  int get estimatedThrownDarts => visits
      .where((v) => v.player == playerIndex && v.thrownDarts == null)
      .fold<int>(0, (sum, v) => sum + v.darts);
  ScorerPlayerStatistics get statistics => ScorerStatistics.calculate(
    visits,
    playerCount: names.length,
    startScores: startScores,
    standard501Rules: standard501Rules,
  ).players[playerIndex];

  Map<String, dynamic> toJson() => {
    'schemaVersion': 3,
    'pendingDarts': pendingDarts,
    'isDraw': isDraw,
    'id': id,
    'accountId': accountId,
    'playedAt': playedAt.toUtc().toIso8601String(),
    'playerIndex': playerIndex,
    'names': names,
    'startScores': startScores,
    'standard501Rules': standard501Rules,
    'doubleOut': doubleOut,
    'winner': winner,
    'visits': [
      for (final v in visits)
        {
          'player': v.player,
          'leg': v.leg,
          'starter': v.starter,
          'points': v.points,
          'darts': v.darts,
          'thrownDarts': v.thrownDarts,
          'remaining': v.remaining,
          'bust': v.bust,
          'checkoutAttempts': v.checkoutAttempts,
        },
    ],
  };

  factory SavedScorerMatch.fromJson(Map<String, dynamic> json) {
    if (![1, 2, 3].contains(json['schemaVersion'])) {
      throw const FormatException('Unbekannte Statistikversion');
    }
    return SavedScorerMatch(
      id: json['id'] as String,
      accountId: json['accountId'] as String,
      playedAt: DateTime.parse(json['playedAt'] as String),
      playerIndex: json['playerIndex'] as int,
      names: List<String>.from(json['names'] as List),
      startScores: List<int>.from(json['startScores'] as List),
      standard501Rules: json['standard501Rules'] as bool,
      doubleOut: json['doubleOut'] as bool,
      winner: json['winner'] as int?,
      isDraw: json['isDraw'] as bool? ?? false,
      pendingDarts: json['pendingDarts'] as int? ?? 0,
      visits: [
        for (final raw in json['visits'] as List)
          ScorerVisit(
            player: raw['player'] as int,
            leg: raw['leg'] as int,
            starter: raw['starter'] as int,
            points: raw['points'] as int,
            darts: raw['darts'] as int,
            thrownDarts: raw['thrownDarts'] as int?,
            remaining: raw['remaining'] as int,
            bust: raw['bust'] as bool,
            checkoutAttempts: raw['checkoutAttempts'] as int?,
          ),
      ],
    );
  }
}

class PersonalScorerTotals {
  PersonalScorerTotals(Iterable<SavedScorerMatch> matches) {
    for (final match in matches) {
      final p = match.statistics;
      if (p.visits == 0) continue;
      sessions++;
      if (match.winner != null || match.isDraw) completed++;
      if (match.winner == match.playerIndex) wins++;
      points += p.points;
      darts += p.darts;
      scores180 += p.scores180;
      legs += p.legsPlayed;
      legsWon += p.legsWon;
      if (p.highestFinish > highestFinish) highestFinish = p.highestFinish;
      if (match.doubleOut) {
        attempts += p.checkoutAttempts;
        finishes += p.legsWon;
        unknownAttempts += p.unknownCheckoutVisits;
      }
    }
  }
  int sessions = 0,
      completed = 0,
      wins = 0,
      points = 0,
      darts = 0,
      scores180 = 0,
      legs = 0,
      legsWon = 0,
      highestFinish = 0,
      attempts = 0,
      finishes = 0,
      unknownAttempts = 0;
  double? get average => darts == 0 ? null : 3 * points / darts;
  double? get checkoutPercent =>
      attempts == 0 || unknownAttempts > 0 ? null : 100 * finishes / attempts;
}
