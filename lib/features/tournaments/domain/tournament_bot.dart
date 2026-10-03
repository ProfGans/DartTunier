import '../../scorer/domain/x01/x01_models.dart';

/// Persist the resolved profile so a saved bot keeps its strength after updates.
class TournamentBot {
  const TournamentBot({
    required this.targetAverage,
    required this.skill,
    required this.finishingSkill,
    required this.radius,
    required this.spread,
  });
  final double targetAverage;
  final int skill, finishingSkill, radius, spread;
  BotProfile get profile => BotProfile(
    skill: skill,
    finishingSkill: finishingSkill,
    radiusCalibrationPercent: radius,
    simulationSpreadPercent: spread,
  );
  Map<String, dynamic> toJson() => {
    'version': 1,
    'targetAverage': targetAverage,
    'skill': skill,
    'finishingSkill': finishingSkill,
    'radius': radius,
    'spread': spread,
  };
  factory TournamentBot.fromJson(Map<String, dynamic> json) {
    final average = (json['targetAverage'] as num).toDouble();
    final skill = json['skill'] as int, finish = json['finishingSkill'] as int;
    final radius = json['radius'] as int, spread = json['spread'] as int;
    if (json['version'] != 1 ||
        !average.isFinite ||
        average <= 0 ||
        average > 180 ||
        skill < 1 ||
        skill > 1000 ||
        finish < 1 ||
        finish > 1000 ||
        radius < 1 ||
        radius > 200 ||
        spread < 1 ||
        spread > 200) {
      throw const FormatException('Ungültige Turnier-Bot-Konfiguration');
    }
    return TournamentBot(
      targetAverage: average,
      skill: skill,
      finishingSkill: finish,
      radius: radius,
      spread: spread,
    );
  }
  @override
  bool operator ==(Object other) =>
      other is TournamentBot &&
      targetAverage == other.targetAverage &&
      skill == other.skill &&
      finishingSkill == other.finishingSkill &&
      radius == other.radius &&
      spread == other.spread;
  @override
  int get hashCode =>
      Object.hash(targetAverage, skill, finishingSkill, radius, spread);
}
