import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_tournament_manager/features/autoscoring/application/autoscoring_controller.dart';
import 'package:dart_tournament_manager/features/autoscoring/domain/board_geometry.dart';
import 'package:dart_tournament_manager/features/autoscoring/presentation/widgets/scorer_camera_panel.dart';
import 'package:dart_tournament_manager/features/autoscoring/presentation/widgets/flat_board_view.dart';
import 'package:dart_tournament_manager/features/scorer/domain/x01/x01_models.dart';
import 'package:dart_tournament_manager/features/scorer/domain/x01/x01_rules.dart';

class _Camera extends AutoscoringController {
  @override
  Future<void> discover() async {}
}

void main() {
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
      expect(
        tester
            .widget<FlatBoardView>(find.byType(FlatBoardView))
            .markers
            .single
            .label,
        'BULL',
      );
      await Scrollable.ensureVisible(
        tester.element(find.text('Aufnahme übernehmen')),
        alignment: .5,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Aufnahme übernehmen'));
      expect(accepted!.single.scoredPoints, 50);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
