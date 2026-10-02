import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_tournament_manager/features/scorer/application/theo_average_service.dart';
import 'package:dart_tournament_manager/features/scorer/domain/bot_settings.dart';
import 'package:dart_tournament_manager/features/scorer/domain/theo_resolution_lookup.dart';
import 'package:dart_tournament_manager/features/scorer/data/generated_theo_lookup_table.dart';
import 'package:dart_tournament_manager/features/scorer/data/bot_settings_storage.dart';
import 'package:dart_tournament_manager/features/scorer/data/repositories/checkout_route_repository.dart';
import 'package:dart_tournament_manager/features/scorer/presentation/bot_settings_page.dart';
import 'package:dart_tournament_manager/features/scorer/presentation/scorer_page.dart';
import 'package:dart_tournament_manager/features/scorer/presentation/scorer_match_page.dart';

void main() {
  test('Theo input accepts decimal comma and rejects invalid values', () {
    expect(TheoAverageService.parse(' 60,5 '), 60.5);
    for (final s in ['NaN', 'Infinity', '0', '-1', '181', '']) {
      expect(TheoAverageService.parse(s), isNull);
    }
  });
  test('Lookup uses exact imported skill pairs at calibrated radius', () async {
    for (final radius in [90, 100, 110]) {
      final settings = BotSettings(radiusPercent: radius);
      final packed =
          kTheoLookupSkillPairsByEffectiveRadius[settings
              .profile()
              .radiusCalibrationPercent]!;
      for (final target in [35.0, 60.5, 90.0, 120.0]) {
        final result = await TheoAverageService.resolve(target, settings);
        final offset = ((target * 10).round() - 350) * 2;
        expect(result.skill, packed[offset]);
        expect(result.finishingSkill, packed[offset + 1]);
      }
    }
  });
  test('Fallback uses estimator for unsupported calibration', () {
    final result = TheoResolutionLookup.resolve(
      targetAverage: 60.5,
      effectiveRadiusCalibrationPercent: 50,
      effectiveSimulationSpreadPercent: 90,
      minSupportedEffectiveRadiusCalibrationPercent: 77,
      maxSupportedEffectiveRadiusCalibrationPercent: 94,
      fixedSupportedEffectiveSimulationSpreadPercent: 115,
      estimateAverage: (s, f) => (s + f) / 20,
    );
    expect(result.theoreticalAverage, closeTo(60.5, .1));
  });
  test('Settings migration preserves manual strength and roundtrips Theo', () {
    final migrated = BotSettings.fromJson({
      'schemaVersion': 1,
      'skill': 751,
      'finishingSkill': 432,
    });
    expect(migrated.useTheoAverage, false);
    expect(migrated.skill, 751);
    expect(migrated.finishingSkill, 432);
    expect(migrated.toJson()['schemaVersion'], 2);
    const current = BotSettings(theoAverage: 72.3);
    expect(BotSettings.fromJson(current.toJson()).theoAverage, 72.3);
    expect(BotSettings.fromJson(current.toJson()).useTheoAverage, true);
  });
  testWidgets('Theo settings save comma input and resolved skills', (
    tester,
  ) async {
    final storage = _Storage();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: BotSettingsPanel(storage: storage)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '60,5');
    await tester.scrollUntilVisible(
      find.text('Einstellungen speichern'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Einstellungen speichern'));
    await tester.pumpAndSettle();
    expect(
      storage.value.theoAverage,
      60.5,
      reason: tester
          .widgetList<Text>(find.byType(Text))
          .map((w) => w.data)
          .join(' | '),
    );
    final expected = await TheoAverageService.resolve(
      60.5,
      const BotSettings(),
    );
    expect(storage.value.skill, expected.skill);
    expect(storage.value.finishingSkill, expected.finishingSkill);
  });
  testWidgets('Match start converts Theo target into actual bot profile', (
    tester,
  ) async {
    await tester.runAsync(() => CheckoutRouteRepository.instance.initialize());
    final storage = _Storage()..value = const BotSettings(theoAverage: 72.3);
    await tester.pumpWidget(MaterialApp(home: ScorerPage(botStorage: storage)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gegen Bot spielen'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Spiel starten'),
      350,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Spiel starten'));
    await tester.pumpAndSettle();
    final actual = tester
        .widget<ScorerMatchPage>(find.byType(ScorerMatchPage))
        .settings
        .participants[1]
        .bot!;
    final expected = await TheoAverageService.resolve(72.3, storage.value);
    expect(actual.skill, expected.skill);
    expect(actual.finishingSkill, expected.finishingSkill);
    expect(tester.takeException(), isNull);
  });
}

class _Storage extends BotSettingsStorage {
  BotSettings value = const BotSettings();
  @override
  Future<BotSettings> load() async => value;
  @override
  Future<void> save(BotSettings settings) async {
    value = settings;
  }
}
