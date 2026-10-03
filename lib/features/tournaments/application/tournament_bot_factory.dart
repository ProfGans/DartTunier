import 'dart:math';
import '../../scorer/application/theo_average_service.dart';
import '../../scorer/domain/bot_settings.dart';
import '../domain/tournament_bot.dart';
import '../domain/tournament_models.dart';

class TournamentBotFactory {
  static Future<TournamentBot> resolve(double average) async {
    const tuning = BotSettings();
    final result = await TheoAverageService.resolve(average, tuning);
    final profile = tuning.profile(
      scoring: result.skill,
      finishing: result.finishingSkill,
    );
    return TournamentBot(
      targetAverage: average,
      skill: profile.skill,
      finishingSkill: profile.finishingSkill,
      radius: profile.radiusCalibrationPercent,
      spread: profile.simulationSpreadPercent,
    );
  }

  static Future<List<TournamentPlayer>> create({
    required int count,
    required double minimum,
    required double maximum,
    required Iterable<String> existingNames,
    String name = '',
    Random? random,
  }) async {
    if (count < 1 ||
        count > 128 ||
        !minimum.isFinite ||
        !maximum.isFinite ||
        minimum <= 0 ||
        maximum > 180 ||
        minimum > maximum) {
      throw ArgumentError(
        '1–128 Bots und gültigen Average-Bereich von über 0 bis 180 angeben.',
      );
    }
    final rng = random ?? Random();
    final names = existingNames.toSet();
    final players = <TournamentPlayer>[];
    var index = 1;
    for (var i = 0; i < count; i++) {
      final average = minimum == maximum
          ? minimum
          : ((minimum + rng.nextDouble() * (maximum - minimum)) * 10).round() /
                10;
      final target = average.clamp(minimum, maximum).toDouble();
      var label = count == 1 && name.trim().isNotEmpty
          ? name.trim()
          : 'Bot ${index++}';
      final base = label;
      var suffix = 2;
      while (names.contains(label)) {
        label = '$base (${suffix++})';
      }
      names.add(label);
      players.add(
        TournamentPlayer(
          name: label,
          isGenerated: false,
          bot: await resolve(target),
        ),
      );
    }
    return players;
  }
}
