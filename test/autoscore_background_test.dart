import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dart_tournament_manager/features/autoscoring/application/autoscore_lifecycle_policy.dart';
import 'package:dart_tournament_manager/features/autoscoring/application/autoscoring_controller.dart';
import 'package:dart_tournament_manager/features/autoscoring/data/autoscore_setup_store.dart';
import 'package:dart_tournament_manager/features/autoscoring/presentation/widgets/scorer_camera_panel.dart';
import 'package:dart_tournament_manager/features/autoscoring/presentation/autoscoring_page.dart';
import 'package:dart_tournament_manager/features/scorer/domain/x01/x01_rules.dart';
import 'package:dart_tournament_manager/features/scorer/domain/x01/x01_models.dart';

class _Camera extends AutoscoringController {
  int stops = 0, resumes = 0;
  @override
  Future<void> discover() async {}
  @override
  Future<void> stop() async {
    stops++;
    running = false;
  }

  @override
  bool resumeRecognition() {
    resumes++;
    running = true;
    return true;
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  for (final platform in [
    TargetPlatform.windows,
    TargetPlatform.linux,
    TargetPlatform.macOS,
  ]) {
    test('$platform keeps capture active until detached', () {
      for (final state in AppLifecycleState.values) {
        expect(
          pauseAutoscoreForLifecycle(state, platform: platform),
          state == AppLifecycleState.detached,
        );
      }
    });
  }
  test('Mobile capture only runs in foreground', () {
    for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
      for (final state in AppLifecycleState.values) {
        expect(
          pauseAutoscoreForLifecycle(state, platform: platform),
          state != AppLifecycleState.resumed,
        );
      }
    }
  });
  for (final platform in [TargetPlatform.windows, TargetPlatform.android]) {
    testWidgets('Calibration page lifecycle on $platform', (tester) async {
      debugDefaultTargetPlatformOverride = platform;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final camera = _Camera();
      await tester.pumpWidget(
        MaterialApp(home: AutoscoringPage(controller: camera)),
      );
      await tester.pumpAndSettle();
      camera.running = true;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      expect(camera.running, platform == TargetPlatform.windows);
      expect(
        camera.stops,
        platform == TargetPlatform.windows ? 0 : greaterThan(0),
      );
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpWidget(const SizedBox());
      camera.dispose();
        debugDefaultTargetPlatformOverride = null;
    });
  }
  testWidgets(
    'Minimized desktop keeps counting and resets a visit without rebuilding',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final store = AutoscoreSetupStore();
      await store.load();
      final camera = _Camera();
      final activity = ValueNotifier(true);
      var remaining = 3;
      List<DartThrowResult>? accepted;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ScorerCameraPanel(
                controller: camera,
                setupStore: store,
                activity: activity,
                isInputEnabled: () => activity.value,
                dartsLeftProvider: () => remaining,
                onAccept: (darts) => accepted = darts,
                onClose: () {},
                dartsLeft: 3,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      camera.running = true;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      expect(camera.running, isTrue);
      expect(camera.stops, 0);
      for (var i = 0; i < 3; i++) {
        expect(
          camera.onAutomaticThrow!(const X01Rules().createSingle(20)),
          isTrue,
        );
      }
      camera.onAutomaticVisitCleared!();
      expect(
        accepted!.fold<int>(0, (sum, dart) => sum + dart.scoredPoints),
        60,
      );
      expect(store.active.correct, 3);
      // The bot starts while Flutter is not producing UI frames.
      activity.value = false;
      expect(camera.running, isFalse);
      expect(
        camera.onAutomaticThrow!(const X01Rules().createSingle(20)),
        isFalse,
      );
      remaining = 2;
      activity.value = true;
      expect(camera.running, isTrue);
      expect(camera.resumes, 1);
      expect(camera.automaticVisitDartLimit, 2);
      expect(store.active.total, 3);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(camera.resumes, 1);
      await tester.pumpWidget(const SizedBox());
      await store.flush();
      activity.dispose();
      store.dispose();
      camera.dispose();
      debugDefaultTargetPlatformOverride = null;
    },
  );
}
