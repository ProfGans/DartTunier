import 'x01/x01_models.dart';

/// Display percentages and conversion match the source app's settings v9.
class BotSettings {
  const BotSettings({
    this.skill = 500,
    this.finishingSkill = 500,
    this.radiusPercent = 100,
    this.spreadPercent = 100,
    this.speedIndex = 1,
    this.theoAverage = 60,
    this.useTheoAverage = true,
  });
  final int skill, finishingSkill, radiusPercent, spreadPercent, speedIndex;
  final double theoAverage;
  final bool useTheoAverage;
  Duration get throwDelay =>
      Duration(milliseconds: [1200, 650, 250][speedIndex]);
  BotProfile profile({int? scoring, int? finishing}) => BotProfile(
    skill: scoring ?? skill,
    finishingSkill: finishing ?? finishingSkill,
    radiusCalibrationPercent: (radiusPercent * 93 * 92 / 10000).round(),
    simulationSpreadPercent: (spreadPercent * 115 / 100).round(),
  );
  Map<String, dynamic> toJson() => {
    'schemaVersion': 2,
    'theoAverage': theoAverage,
    'useTheoAverage': useTheoAverage,
    'skill': skill,
    'finishingSkill': finishingSkill,
    'radiusPercent': radiusPercent,
    'spreadPercent': spreadPercent,
    'speedIndex': speedIndex,
  };
  factory BotSettings.fromJson(Map<String, dynamic> json) {
    if (json['schemaVersion'] != 1 && json['schemaVersion'] != 2) {
      throw const FormatException('Unbekannte Bot-Einstellungsversion');
    }
    int read(String key, int fallback, int min, int max) {
      final value = json[key];
      return value is num ? value.toInt().clamp(min, max) : fallback;
    }

    return BotSettings(
      skill: read('skill', 500, 1, 1000),
      finishingSkill: read('finishingSkill', 500, 1, 1000),
      radiusPercent: read('radiusPercent', 100, 50, 150),
      spreadPercent: read('spreadPercent', 100, 70, 140),
      speedIndex: read('speedIndex', 1, 0, 2),
      theoAverage:
          json['theoAverage'] is num &&
              (json['theoAverage'] as num).isFinite &&
              (json['theoAverage'] as num) > 0 &&
              (json['theoAverage'] as num) <= 180
          ? (json['theoAverage'] as num).toDouble()
          : 60,
      // Preserve existing manually tuned skills when migrating v1.
      useTheoAverage: json['schemaVersion'] == 1
          ? false
          : json['useTheoAverage'] != false,
    );
  }
}
