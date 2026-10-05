import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_tournament_manager/features/autoscoring/application/autoscoring_controller.dart';
import 'package:dart_tournament_manager/features/autoscoring/application/capture_general_diagnostic.dart';
import 'package:dart_tournament_manager/features/autoscoring/data/autoscore_diagnostic_export.dart';
import 'package:dart_tournament_manager/features/autoscoring/presentation/widgets/general_diagnostic_button.dart';

void main() {
  test('General report works without cameras and never resets recognition', () {
    final controller = AutoscoringController();
    controller.busy = true;
    controller.status = 'Kamera reagiert nicht';
    controller.lastCaptureError = 'USB disconnected';
    final evidence = captureGeneralDiagnostic(
      controller,
      setupId: 'test-setup',
    );
    evidence.hit['userDescription'] = 'Unbekannter Fehler';
    controller.status = 'Späterer Zustand';
    expect(evidence.hit['recognitionStatus'], 'Kamera reagiert nicht');
    expect(evidence.hit['missingCameraImages'], 3);
    expect(evidence.hit['setupId'], 'test-setup');
    expect(evidence.hit['lastCaptureError'], 'USB disconnected');
    expect(controller.waitingForEmpty, isFalse);
    expect(controller.busy, isTrue);
    final zip = ZipDecoder().decodeBytes(
      const AutoscoreDiagnosticExport().encode(
        evidence,
        'Allgemeine Diagnose',
        'Keine Trefferkorrektur',
      ),
    );
    final report = jsonDecode(
      utf8.decode(zip.findFile('bericht.json')!.content as List<int>),
    );
    expect(report.toString(), contains('Unbekannter Fehler'));
    expect(
      utf8.decode(zip.findFile('LESEN.txt')!.content as List<int>),
      contains('Keine Trefferkorrektur'),
    );
    controller.dispose();
  });
  for (final size in [
    const Size(360, 800),
    const Size(800, 600),
    const Size(1440, 900),
  ]) {
    testWidgets('Diagnostic button and dialog at $size with large text', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = AutoscoringController()..busy = true;
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: size,
              textScaler: const TextScaler.linear(2),
            ),
            child: Scaffold(
              body: SingleChildScrollView(
                child: GeneralDiagnosticButton(controller: controller),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Allgemeine Diagnose erstellen'));
      await tester.pumpAndSettle();
      expect(find.text('Allgemeine Diagnose'), findsOneWidget);
      await tester.enterText(
        find.byType(TextField),
        'Fehler nach dem ersten Dart',
      );
      await tester.ensureVisible(find.text('Abbrechen'));
      await tester.tap(find.text('Abbrechen'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(controller.busy, isTrue);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    });
  }
}
