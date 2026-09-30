import 'package:flutter/foundation.dart';
import '../domain/bot/bot_engine.dart';
import '../domain/bot_settings.dart';
import '../domain/theo_resolution_lookup.dart';
import '../domain/x01/x01_models.dart';

class TheoAverageService {
  static final _cache = <String, TheoLookupResolution>{};
  static double? parse(String value) {
    final result = double.tryParse(value.trim().replaceAll(',', '.'));
    return result != null && result.isFinite && result > 0 && result <= 180
        ? result
        : null;
  }

  static Future<TheoLookupResolution> resolve(
    double target,
    BotSettings settings,
  ) async {
    if (!target.isFinite || target <= 0 || target > 180) {
      throw ArgumentError(
        'Theo-Average muss größer als 0 und höchstens 180 sein.',
      );
    }
    final profile = settings.profile();
    final key =
        '$target/${profile.radiusCalibrationPercent}/${profile.simulationSpreadPercent}';
    final cached = _cache[key];
    if (cached != null) return cached;
    final prepared = TheoResolutionLookup.resolvePrecomputed(
      targetAverage: target,
      effectiveRadiusCalibrationPercent: profile.radiusCalibrationPercent,
      effectiveSimulationSpreadPercent: profile.simulationSpreadPercent,
      minSupportedEffectiveRadiusCalibrationPercent: 77,
      maxSupportedEffectiveRadiusCalibrationPercent: 94,
      fixedSupportedEffectiveSimulationSpreadPercent: 115,
    );
    final result =
        prepared ??
        await compute<(double, BotProfile), TheoLookupResolution>(_resolve, (
          target,
          profile,
        ));
    _cache[key] = result;
    return result;
  }
}

TheoLookupResolution _resolve((double, BotProfile) request) {
  final (target, profile) = request;
  final engine = BotEngine();
  return TheoResolutionLookup.resolve(
    targetAverage: target,
    effectiveRadiusCalibrationPercent: profile.radiusCalibrationPercent,
    effectiveSimulationSpreadPercent: profile.simulationSpreadPercent,
    minSupportedEffectiveRadiusCalibrationPercent: 77,
    maxSupportedEffectiveRadiusCalibrationPercent: 94,
    fixedSupportedEffectiveSimulationSpreadPercent: 115,
    estimateAverage: (skill, finish) => engine.estimateThreeDartAverage(
      BotProfile(
        skill: skill,
        finishingSkill: finish,
        radiusCalibrationPercent: profile.radiusCalibrationPercent,
        simulationSpreadPercent: profile.simulationSpreadPercent,
      ),
    ),
  );
}
