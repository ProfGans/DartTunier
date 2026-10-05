import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dart_tournament_manager/features/autoscoring/data/autoscore_setup_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_tournament_manager/features/autoscoring/application/autoscoring_controller.dart';
import 'package:dart_tournament_manager/features/autoscoring/domain/board_geometry.dart';
import 'package:dart_tournament_manager/features/autoscoring/presentation/widgets/scorer_camera_panel.dart';
import 'package:dart_tournament_manager/features/autoscoring/presentation/widgets/flat_board_view.dart';
import 'package:dart_tournament_manager/features/scorer/domain/x01/x01_models.dart';
import 'package:dart_tournament_manager/features/scorer/domain/x01/x01_rules.dart';
import 'package:dart_tournament_manager/features/scorer/domain/scorer_hit.dart';
import 'package:dart_tournament_manager/features/autoscoring/presentation/widgets/dart_position_dialog.dart';

class _Camera extends AutoscoringController {
  int connects = 0, calibrations = 0;
  @override
  Future<void> connect(List<int> indices) async {
    connects++;
  }

  @override
  Future<void> autoCalibrate() async {
    calibrations++;
  }

  @override
  bool recordMissedThrow(DartThrowResult result) {
    this.throws.add(result);
    return true;
  }

  int stops = 0, resumes = 0;
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

  @override
  Future<void> discover() async {}
}

void main() {
  testWidgets(
    'Deleting detections reopens the visit and preserves dart order',
    (tester) async {
      final camera = _Camera();
      List<DartThrowResult> preview = [];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ScorerCameraPanel(
                controller: camera,
                dartsLeft: 3,
                onAccept: (_) {},
                onClose: () {},
                onPreview: (darts, _) {
                  preview = darts;
                  return darts.length == 3;
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (final score in [20, 5, 1]) {
        final dart = const X01Rules().createSingle(score);
        camera.throws.add(dart);
        camera.onAutomaticThrow!(dart);
      }
      await tester.pumpAndSettle();
      expect(camera.automaticVisitDartLimit, 3);
      Future<void> remove(String label) async {
        final button = find.text(label);
        await Scrollable.ensureVisible(tester.element(button), alignment: .5);
        await tester.pumpAndSettle();
        await tester.tap(button);
        await tester.pumpAndSettle();
      }

      await remove('Dart 2 (5) entfernen');
      expect(preview.map((d) => d.label), ['20', '1']);
      expect(camera.throws.map((d) => d.label), ['20', '1']);
      expect(camera.automaticVisitDartLimit, 3);
      await remove('Dart 1 (20) entfernen');
      await remove('Dart 1 (1) entfernen');
      expect(preview, isEmpty);
      expect(camera.throws, isEmpty);
      final next = const X01Rules().createSingle(19);
      camera.throws.add(next);
      camera.onAutomaticThrow!(next);
      await tester.pumpAndSettle();
      expect(preview.single.label, '19');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      camera.dispose();
    },
  );
  testWidgets(
    'Returning from setup preserves controller and restores callbacks after route disposal',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final camera = _Camera();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ScorerCameraPanel(
                controller: camera,
                dartsLeft: 3,
                onAccept: (_) {},
                onClose: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final connects = camera.connects;
      await tester.tap(find.byTooltip('Kameras einrichten'));
      await tester.pumpAndSettle();
      // Simulate the user successfully calibrating in the shared setup controller.
      await camera.autoCalibrate();
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(camera.calibrations, 1);
      expect(camera.connects, connects);
      expect(camera.stops, 0);
      expect(camera.onAutomaticThrow, isNotNull);
      camera.onAutomaticThrow!(const X01Rules().createSingle(20));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FlatBoardView>(find.byType(FlatBoardView))
            .markers
            .single
            .label,
        '20',
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      camera.dispose();
    },
  );
  testWidgets('Missing dart overrides stopped recognition without cameras', (
    tester,
  ) async {
    final camera = _Camera();
    List<DartThrowResult> preview = [];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ScorerCameraPanel(
              controller: camera,
              dartsLeft: 3,
              onAccept: (_) {},
              onClose: () {},
              onPreview: (darts, _) {
                preview = darts;
                return darts.length == 3;
              },
            ),
          ),
        ),
      ),
    );
    camera.running = true;
    camera.throws.add(const X01Rules().createSingle(20));
    camera.onAutomaticThrow!(const X01Rules().createSingle(20));
    await tester.pumpAndSettle();
    final button = find.text('Nicht erkannten Dart nachtragen');
    camera.pauseRecognition();
    await Scrollable.ensureVisible(tester.element(button), alignment: .5);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(camera.running, false);
    await tester.tap(find.text('Dart 1 · vor 20 einfügen'));
    await tester.pumpAndSettle();
    final board = find.descendant(
      of: find.byType(DartPositionDialog),
      matching: find.byType(FlatBoardView),
    );
    tester.widget<FlatBoardView>(board).onPlaced!(const Point(0.0, -103.0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Position speichern'));
    await tester.pumpAndSettle();
    expect(preview.map((d) => d.label), ['T20', '20']);
    expect(camera.throws.map((d) => d.label), ['T20', '20']);
    expect(camera.running, false);
    final confirm = find.text('Pfeile gezogen · Aufnahme bestätigen');
    await Scrollable.ensureVisible(tester.element(confirm), alignment: .5);
    await tester.pumpAndSettle();
    await tester.tap(confirm);
    await tester.pumpAndSettle();
    expect(camera.throws, isEmpty);
    expect(camera.running, false);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    camera.dispose();
  });
  testWidgets(
    'Match corrections and removal update the originating setup once',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final store = AutoscoreSetupStore();
      await store.load();
      final camera = _Camera();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ScorerCameraPanel(
                controller: camera,
                setupStore: store,
                onAccept: (_) {},
                onClose: () {},
                dartsLeft: 3,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (var i = 0; i < 3; i++) {
        camera.lastHit = const FusedHit(Point(0, -120), 0, 3);
        camera.onAutomaticThrow!(const X01Rules().createSingle(20));
      }
      await tester.pump();
      store.create('Anderes Setup');
      final board = tester.widget<FlatBoardView>(find.byType(FlatBoardView));
      board.onMoved(0, const Point(0, -170));
      board.onMoved(0, const Point(0, -165));
      camera.onAutomaticVisitCleared!();
      camera.onAutomaticVisitCleared!();
      expect(store.active.total, 0);
      expect(store.setups.first.total, 3);
      expect(store.setups.first.correct, 2);
      expect(store.setups.first.incorrect, 1);
      expect(store.setups.first.accuracy, closeTo(66.6667, .001));
      await tester.pumpWidget(const SizedBox());
      await store.flush();
      store.dispose();
      camera.dispose();
    },
  );
  testWidgets('Focus loss keeps pending darts and resumes without disconnect', (
    tester,
  ) async {
    final camera = _Camera();
    await tester.pumpWidget(
      MaterialApp(
        home: SingleChildScrollView(
          child: ScorerCameraPanel(
            controller: camera,
            onAccept: (_) {},
            onClose: () {},
            dartsLeft: 3,
          ),
        ),
      ),
    );
    camera.running = true;
    camera.onAutomaticThrow!(const X01Rules().createSingle(20));
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect(camera.running, false);
    expect(camera.stops, 0);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(camera.running, true);
    expect(camera.resumes, 1);
    expect(
      tester
          .widget<FlatBoardView>(find.byType(FlatBoardView))
          .markers
          .single
          .label,
      '20',
    );
    await tester.pumpWidget(const SizedBox());
    camera.dispose();
  });
  for (final size in [
    const Size(360, 800),
    const Size(800, 600),
    const Size(1440, 900),
  ]) {
    testWidgets('Compact board correction before commit at $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final camera = _Camera();
      addTearDown(camera.dispose);
      List<DartThrowResult>? accepted;
      List<DartLocation?>? locations;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MediaQuery(
              data: MediaQueryData(
                size: size,
                textScaler: const TextScaler.linear(2),
              ),
              child: SingleChildScrollView(
                child: ScorerCameraPanel(
                  controller: camera,
                  onAccept: (value) => accepted = value,
                  onLocations: (value) => locations = value,
                  onClose: () {},
                  dartsLeft: 3,
                ),
              ),
            ),
          ),
        ),
      );
      camera.lastHit = const FusedHit(
        Point(0, -120),
        0,
        2,
        forcedDecision: true,
      );
      camera.onAutomaticThrow!(const X01Rules().createSingle(20));
      await tester.pump();
      expect(accepted, isNull);
      expect(locations!.single!.estimated, true);
      expect(find.textContaining('Dart 1: Schätzung · prüfen'), findsOneWidget);
      expect(find.textContaining('2/3 Kameras'), findsOneWidget);
      expect(locations!.single!.y, -120);
      expect(
        tester
            .widget<FlatBoardView>(find.byType(FlatBoardView))
            .markers
            .single
            .label,
        contains('Schätzung'),
      );
      tester
          .widget<FlatBoardView>(find.byType(FlatBoardView))
          .onMoved(0, const Point(0, 0));
      await tester.pump();
      expect(locations!.single!.corrected, true);
      expect(find.textContaining('Dart 1: Manuell korrigiert'), findsOneWidget);
      expect(locations!.single!.estimated, false);
      expect(locations!.single!.y, 0);
      expect(
        tester
            .widget<FlatBoardView>(find.byType(FlatBoardView))
            .markers
            .single
            .label,
        'BULL',
      );
      camera.onAutomaticVisitCleared!();
      expect(accepted!.single.scoredPoints, 50);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
