import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dart_tournament_manager/features/autoscoring/data/autoscore_setup_store.dart';
import 'package:dart_tournament_manager/features/autoscoring/application/autoscore_demo_controller.dart';
import 'package:dart_tournament_manager/features/scorer/domain/x01/x01_rules.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'Reset is isolated, persisted, and rejects reviews from before reset',
    () async {
      final store = AutoscoreSetupStore();
      await store.load();
      store.saveSettings(cameras: ['USB1'], caller: false, volume: .4);
      final correct = store.record(estimated: true);
      final pending = store.record(missing: true, bounce: true);
      store.review(correct, corrected: false);
      store.create('Andere');
      final other = store.record();
      store.review(other, corrected: true);
      store.resetStatistics('default');
      store.review(correct, corrected: true);
      store.review(pending, corrected: false);
      expect(store.active.incorrect, 1);
      store.select('default');
      expect(store.active.accuracy, isNull);
      expect([
        store.active.total,
        store.active.correct,
        store.active.incorrect,
        store.active.pending,
        store.active.estimated,
        store.active.missing,
        store.active.bouncers,
      ], everyElement(0));
      expect(store.active.cameraKeys, ['USB1']);
      expect(store.active.caller, false);
      expect(store.active.volume, .4);
      final fresh = store.record();
      store.review(fresh, corrected: false);
      expect(store.active.accuracy, 100);
      await store.flush();
      final restored = AutoscoreSetupStore();
      await restored.load();
      expect(restored.active.total, 1);
      expect(restored.active.correct, 1);
      expect(restored.setups.last.incorrect, 1);
      store.dispose();
      restored.dispose();
    },
  );
  test(
    'Resetting demo accuracy preserves scores, history and diagnoses',
    () async {
      final store = AutoscoreSetupStore();
      await store.load();
      final controller = AutoscoreDemoController(setupStore: store);
      controller.add(const X01Rules().createSingle(20));
      controller.confirm(0);
      controller.history.first.diagnosticPath = 'diagnose.zip';
      store.resetStatistics(store.active.id);
      controller.resetAccuracy();
      expect(controller.accuracyPercent, isNull);
      expect(controller.uncheckedCount, 0);
      expect(controller.totalPoints, 20);
      expect(controller.history.first.diagnosticPath, 'diagnose.zip');
      controller.review(0, const X01Rules().createSingle(5));
      controller.reset();
      expect(store.active.total, 0);
      controller.add(const X01Rules().createSingle(1));
      controller.reset();
      expect(controller.accuracyPercent, 100);
      expect(store.active.correct, 1);
      await store.flush();
      controller.dispose();
      store.dispose();
    },
  );
  test(
    'Removal confirms untouched throws and correction is sticky without double counting',
    () async {
      final store = AutoscoreSetupStore();
      await store.load();
      final controller = AutoscoreDemoController(setupStore: store);
      controller.add(const X01Rules().createSingle(20));
      controller.add(const X01Rules().createSingle(5));
      controller.review(1, const X01Rules().createSingle(1));
      controller.reset();
      controller.reset();
      expect(store.active.total, 2);
      expect(store.active.accuracy, 50);
      controller.review(0, const X01Rules().createSingle(20));
      controller.review(0, const X01Rules().createSingle(20));
      controller.confirm(0);
      expect(store.active.correct, 0);
      expect(store.active.incorrect, 2);
      expect(store.active.pending, 0);
      await store.flush();
      controller.dispose();
      store.dispose();
    },
  );
  test(
    'Late correction remains assigned to the original setup and survives restart',
    () async {
      final store = AutoscoreSetupStore();
      await store.load();
      final token = store.record(estimated: true, bounce: true);
      final original = store.active.id;
      store.review(token, corrected: false);
      store.create('Anderer Kameraaufbau');
      store.record(missing: true);
      store.review(token, corrected: true);
      expect(store.active.total, 1);
      expect(store.active.pending, 1);
      expect(store.setups.first.incorrect, 1);
      expect(store.setups.first.estimated, 1);
      await store.flush();
      final restored = AutoscoreSetupStore();
      await restored.load();
      expect(restored.active.name, 'Anderer Kameraaufbau');
      expect(restored.active.missing, 1);
      restored.select(original);
      expect(restored.active.bouncers, 1);
      expect(restored.active.accuracy, 0);
      await restored.flush();
      store.dispose();
      restored.dispose();
    },
  );
  test('Camera and audio settings are isolated between setups', () async {
    final store = AutoscoreSetupStore();
    await store.load();
    store.saveSettings(
      cameras: ['USB#0', 'USB#1', 'USB#2'],
      caller: false,
      volume: .4,
    );
    store.create('Neu');
    store.saveSettings(cameras: ['Andere USB#0'], sounds: false, volume: .8);
    store.select('default');
    expect(store.active.cameraKeys, ['USB#0', 'USB#1', 'USB#2']);
    expect(store.active.sounds, isTrue);
    expect(store.active.volume, .4);
    store.rename('Mein Board');
    await store.flush();
    final restored = AutoscoreSetupStore();
    await restored.load();
    expect(restored.active.name, 'Mein Board');
    expect(restored.active.caller, isFalse);
    await restored.flush();
    store.dispose();
    restored.dispose();
  });
  test(
    'Unknown versions remain untouched and do not collect statistics',
    () async {
      final raw = jsonEncode({'version': 99});
      SharedPreferences.setMockInitialValues({AutoscoreSetupStore.key: raw});
      final store = AutoscoreSetupStore();
      await store.load();
      expect(store.loaded, isFalse);
      expect(store.record(), isNull);
      store.create('Überschreiben');
      await store.flush();
      expect(
        (await SharedPreferences.getInstance()).getString(
          AutoscoreSetupStore.key,
        ),
        raw,
      );
      store.dispose();
    },
  );
}
