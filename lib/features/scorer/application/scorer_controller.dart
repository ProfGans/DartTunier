import 'dart:math';
import 'package:flutter/foundation.dart';
import '../domain/bot/bot_engine.dart';
import '../domain/scorer_settings.dart';
import '../domain/scorer_statistics.dart';
import '../domain/fixed_checkouts.dart';
import '../domain/visit_score_entry.dart';
import '../domain/x01/x01_match_engine.dart';
import '../domain/x01/x01_models.dart';
import '../domain/x01/x01_rules.dart';

class ScorerController extends ChangeNotifier {
  ScorerController(this.settings, {Random? random})
    : random = random ?? Random() {
    activePlayer = settings.startingPlayer;
    legStarter = activePlayer;
    scores = [
      for (final p in settings.participants)
        p.startScore ?? settings.startScore,
    ];
    opened = List.filled(scores.length, false);
    legs = List.filled(scores.length, 0);
    sets = List.filled(scores.length, 0);
  }
  final ScorerSettings settings;
  final Random random;
  final _engine = X01MatchEngine();
  final _bot = BotEngine();
  late List<int> scores, legs, sets;
  late List<bool> opened;
  late int activePlayer, legStarter;
  int? winner;
  List<DartThrowResult> visit = [];
  String message = '';
  final List<_Snapshot> _history = [];
  final List<ScorerVisit> _statisticsVisits = [];
  int _leg = 0;
  int? _visitCheckoutAttempts = 0;
  ScorerStatistics get statistics => ScorerStatistics.calculate(
    _statisticsVisits,
    playerCount: scores.length,
    startScores: [
      for (final p in settings.participants)
        p.startScore ?? settings.startScore,
    ],
    standard501Rules:
        settings.startRequirement == StartRequirement.straightIn &&
        settings.checkoutRequirement == CheckoutRequirement.doubleOut,
  );

  int maxCheckoutAttempts({int darts = 3}) {
    for (var n = 1; n <= darts; n++) {
      if (FixedCheckouts.routes(
        remaining,
        dartsLeft: n,
        requirement: settings.checkoutRequirement,
      ).isNotEmpty) {
        return darts - n + 1;
      }
    }
    return 0;
  }

  int? _validatedAttempts(
    int? attempts, {
    required bool finish,
    required int darts,
  }) {
    final maximum = maxCheckoutAttempts(darts: darts);
    if (attempts != null &&
        (attempts < (finish ? 1 : 0) || attempts > maximum)) {
      throw ArgumentError('Ungültige Anzahl an Checkoutversuchen.');
    }
    return attempts ??
        (maximum == 0
            ? 0
            : finish && maximum == 1
            ? 1
            : null);
  }

  void _recordVisit(VisitResult result, int darts, int? attempts) {
    _statisticsVisits.add(
      ScorerVisit(
        player: activePlayer,
        leg: _leg,
        starter: legStarter,
        points: result.scoredPoints,
        darts: darts,
        remaining: result.remainingScore,
        bust: result.didBust,
        checkoutAttempts: attempts,
      ),
    );
  }

  bool get isBotTurn =>
      winner == null && settings.participants[activePlayer].bot != null;
  bool get canUndo => _history.isNotEmpty;
  int get dartsLeft => 3 - visit.length;
  VisitResult get progress => _engine.evaluateVisit(
    currentScore: scores[activePlayer],
    throws: visit,
    startRequirement: settings.startRequirement,
    hasOpenedLeg: opened[activePlayer],
    checkoutRequirement: settings.checkoutRequirement,
  );
  int get remaining => progress.remainingScore;

  void submitScore(int points, {int? checkoutDarts, int? checkoutAttempts}) {
    if (winner != null || isBotTurn || visit.isNotEmpty) return;
    final result = VisitScoreEntry.evaluate(
      score: remaining,
      points: points,
      start: settings.startRequirement,
      out: settings.checkoutRequirement,
      opened: opened[activePlayer],
      checkoutDarts: checkoutDarts,
    );
    final finish = !result.didBust && result.remainingScore == 0;
    final countedDarts = finish ? checkoutDarts! : 3;
    final attempts = _validatedAttempts(
      checkoutAttempts,
      finish: finish,
      darts: countedDarts,
    );
    _history.add(_Snapshot(this));
    _recordVisit(result, countedDarts, attempts);
    message =
        '${settings.participants[activePlayer].name}: $points Punkte'
        '${checkoutDarts != null ? ' · Checkout in $checkoutDarts Darts' : ''}';
    _completeVisit(result);
    notifyListeners();
  }

  void submitBust({int? checkoutAttempts}) {
    if (winner != null || isBotTurn || visit.isNotEmpty) return;
    final attempts = _validatedAttempts(
      checkoutAttempts,
      finish: false,
      darts: 3,
    );
    _history.add(_Snapshot(this));
    _statisticsVisits.add(
      ScorerVisit(
        player: activePlayer,
        leg: _leg,
        starter: legStarter,
        points: 0,
        darts: 3,
        remaining: remaining,
        bust: true,
        checkoutAttempts: attempts,
      ),
    );
    message = '${settings.participants[activePlayer].name}: Überworfen';
    activePlayer = (activePlayer + 1) % scores.length;
    notifyListeners();
  }

  void throwDart(DartThrowResult dart, {bool? checkoutAttempt}) {
    if (winner != null) return;
    _history.add(_Snapshot(this));
    final canFinish =
        FixedCheckouts.routes(
          remaining,
          dartsLeft: 1,
          requirement: settings.checkoutRequirement,
        ).isNotEmpty &&
        (settings.startRequirement == StartRequirement.straightIn ||
            progress.openedLeg ||
            dart.isFinishDouble);
    final successful =
        dart.scoredPoints == remaining &&
        dart.matchesCheckoutRequirement(settings.checkoutRequirement) &&
        canFinish;
    if (checkoutAttempt == true || successful) {
      if (_visitCheckoutAttempts != null) {
        _visitCheckoutAttempts = _visitCheckoutAttempts! + 1;
      }
    } else if (checkoutAttempt == null && canFinish) {
      _visitCheckoutAttempts = null;
    }
    visit = [...visit, dart];
    final result = progress;
    message =
        '${settings.participants[activePlayer].name}: ${visit.map((d) => d.label).join(' · ')}';
    if (result.didBust || result.remainingScore == 0 || visit.length == 3) {
      _recordVisit(
        result,
        result.remainingScore == 0 && !result.didBust ? visit.length : 3,
        _visitCheckoutAttempts,
      );
      _completeVisit(result);
    }
    notifyListeners();
  }

  void _completeVisit(VisitResult result) {
    scores[activePlayer] = result.remainingScore;
    opened[activePlayer] = result.openedLeg;
    if (result.didBust) message += ' — Überworfen';
    if (!result.didBust && result.remainingScore == 0) {
      _winLeg();
    } else {
      activePlayer = (activePlayer + 1) % scores.length;
    }
    visit = [];
    _visitCheckoutAttempts = 0;
  }

  void _winLeg() {
    _leg++;
    legs[activePlayer]++;
    message += ' — Leg gewonnen';
    final config = settings.matchConfig;
    if (legs[activePlayer] >= config.legsToWin) {
      if (config.mode == MatchMode.legs) {
        winner = activePlayer;
      } else {
        sets[activePlayer]++;
        legs = List.filled(scores.length, 0);
        message += ' — Set gewonnen';
        if (sets[activePlayer] >= config.setsToWin) winner = activePlayer;
      }
    }
    if (winner != null) return;
    scores = [
      for (final p in settings.participants)
        p.startScore ?? settings.startScore,
    ];
    opened = List.filled(scores.length, false);
    legStarter = (legStarter + 1) % scores.length;
    activePlayer = legStarter;
  }

  void playBotDart() {
    if (!isBotTurn) return;
    final profile = settings.participants[activePlayer].bot!;
    final result =
        settings.startRequirement == StartRequirement.doubleIn &&
            !progress.openedLeg
        ? _bot.simulateTargetThrow(
            target: const X01Rules().createDouble(20),
            score: remaining,
            profile: profile,
            random: random,
          )
        : _bot.simulateThrow(
            score: remaining,
            dartsLeft: dartsLeft,
            profile: profile,
            checkoutRequirement: settings.checkoutRequirement,
            random: random,
          );
    final isOpen =
        settings.startRequirement == StartRequirement.straightIn ||
        progress.openedLeg ||
        result.target.isFinishDouble;
    throwDart(
      result.hit,
      checkoutAttempt:
          isOpen &&
          result.target.scoredPoints == remaining &&
          result.target.matchesCheckoutRequirement(
            settings.checkoutRequirement,
          ),
    );
  }

  /// Undo a human dart together with any ensuing bot darts.
  void undo() {
    if (!canUndo) return;
    do {
      _history.removeLast().restore(this);
    } while (isBotTurn && _history.isNotEmpty);
    notifyListeners();
  }
}

class _Snapshot {
  _Snapshot(ScorerController c)
    : scores = [...c.scores],
      legs = [...c.legs],
      sets = [...c.sets],
      opened = [...c.opened],
      visit = [...c.visit],
      active = c.activePlayer,
      starter = c.legStarter,
      winner = c.winner,
      message = c.message,
      leg = c._leg,
      statisticsLength = c._statisticsVisits.length,
      visitCheckoutAttempts = c._visitCheckoutAttempts;
  final int leg, statisticsLength;
  final int? visitCheckoutAttempts;
  final List<int> scores, legs, sets;
  final List<bool> opened;
  final List<DartThrowResult> visit;
  final int active, starter;
  final int? winner;
  final String message;
  void restore(ScorerController c) {
    c.scores = [...scores];
    c.legs = [...legs];
    c.sets = [...sets];
    c.opened = [...opened];
    c.visit = [...visit];
    c.activePlayer = active;
    c.legStarter = starter;
    c.winner = winner;
    c.message = message;
    c._leg = leg;
    c._statisticsVisits.length = statisticsLength;
    c._visitCheckoutAttempts = visitCheckoutAttempts;
  }
}
