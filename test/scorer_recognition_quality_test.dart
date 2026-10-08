import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_tournament_manager/features/autoscoring/domain/board_geometry.dart';
import 'package:dart_tournament_manager/features/autoscoring/presentation/widgets/scorer_recognition_quality.dart';

void main() {
  testWidgets('Corrected dart offers its own diagnostic export', (
    tester,
  ) async {
    int? exported;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ScorerRecognitionQuality(
            hits: const [null, null, null],
            corrected: const [false, false, true],
            diagnosticPath: (i) => i == 2 ? 'third.zip' : null,
            onExportDiagnostic: (i) => exported = i,
          ),
        ),
      ),
    );
    await tester.tap(find.text('Diagnose für Dart 3 speichern'));
    expect(exported, 2);
    expect(find.text('Diagnose für Dart 1 speichern'), findsNothing);
  });
  for (final size in [
    const Size(360, 800),
    const Size(800, 600),
    const Size(1440, 900),
  ]) {
    testWidgets(
      'Quality distinguishes missing, certain and wire hits at $size',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MediaQuery(
                data: MediaQueryData(
                  size: size,
                  textScaler: const TextScaler.linear(2),
                ),
                child: const SingleChildScrollView(
                  child: ScorerRecognitionQuality(
                    hits: [
                      null,
                      FusedHit(Point(0, -120), 1, 3),
                      FusedHit(Point(0, -107), 1, 3),
                    ],
                    corrected: [false, false, false],
                  ),
                ),
              ),
            ),
          ),
        );
        expect(find.textContaining('Keine Position erkannt'), findsOneWidget);
        expect(find.textContaining('Gute Übereinstimmung'), findsOneWidget);
        expect(find.textContaining('nahe am Draht'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
