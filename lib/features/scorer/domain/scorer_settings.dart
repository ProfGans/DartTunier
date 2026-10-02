import 'x01/x01_models.dart';

class ScorerParticipant {
  const ScorerParticipant(
    this.name, {
    this.bot,
    this.startScore,
    this.accountId,
    this.members = const [],
  });
  final String? accountId;
  final String name;
  final List<String> members;
  bool get isTeam => members.length > 1;
  final BotProfile? bot;
  final int? startScore;
}

/// Best-of semantics match TournamentGameFormat. Engine fields count wins.
class ScorerSettings {
  ScorerSettings({
    this.startScore = 501,
    this.bestOfLegs = 3,
    this.bestOfSets = 1,
    this.startRequirement = StartRequirement.straightIn,
    this.checkoutRequirement = CheckoutRequirement.doubleOut,
    this.startingPlayer = 0,
    this.botThrowDelay = const Duration(milliseconds: 650),
    required List<ScorerParticipant> participants,
  }) : participants = List.unmodifiable(participants) {
    if (startScore < 2 ||
        bestOfLegs < 1 ||
        (bestOfLegs.isEven && (bestOfSets != 1 || participants.length != 2)) ||
        bestOfSets < 1 ||
        bestOfSets.isEven ||
        participants.isEmpty ||
        startingPlayer < 0 ||
        startingPlayer >= participants.length ||
        participants.every((p) => p.bot != null) ||
        participants.any(
          (p) =>
              p.name.trim().isEmpty ||
              p.members.any((name) => name.trim().isEmpty) ||
              p.members.toSet().length != p.members.length ||
              (p.startScore != null && p.startScore! < 2),
        )) {
      throw ArgumentError('Ungültige Spieleinstellungen');
    }
  }
  final int startScore, bestOfLegs, bestOfSets, startingPlayer;
  final Duration botThrowDelay;
  final StartRequirement startRequirement;
  final CheckoutRequirement checkoutRequirement;
  final List<ScorerParticipant> participants;
  bool get allowsDraws => bestOfSets == 1 && bestOfLegs.isEven;
  MatchConfig get matchConfig => MatchConfig(
    startScore: startScore,
    mode: bestOfSets == 1 ? MatchMode.legs : MatchMode.sets,
    startRequirement: startRequirement,
    checkoutRequirement: checkoutRequirement,
    legsToWin: bestOfLegs ~/ 2 + 1,
    legsPerSet: bestOfLegs ~/ 2 + 1,
    setsToWin: bestOfSets ~/ 2 + 1,
  );
}
