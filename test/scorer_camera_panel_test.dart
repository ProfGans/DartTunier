import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_tournament_manager/features/autoscoring/application/autoscoring_controller.dart';
import 'package:dart_tournament_manager/features/autoscoring/domain/board_geometry.dart';
import 'package:dart_tournament_manager/features/autoscoring/presentation/widgets/scorer_camera_panel.dart';
import 'package:dart_tournament_manager/features/autoscoring/presentation/widgets/flat_board_view.dart';
import 'package:dart_tournament_manager/features/scorer/domain/x01/x01_models.dart';
import 'package:dart_tournament_manager/features/scorer/domain/x01/x01_rules.dart';
import 'package:dart_tournament_manager/features/scorer/domain/scorer_hit.dart';

class _Camera extends AutoscoringController {
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
