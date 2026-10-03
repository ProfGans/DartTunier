import 'dart:math';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_tournament_manager/features/autoscoring/presentation/widgets/dart_position_dialog.dart';
import 'package:dart_tournament_manager/features/autoscoring/application/autoscore_demo_controller.dart';
import 'package:dart_tournament_manager/features/autoscoring/application/autoscoring_controller.dart';
import 'package:dart_tournament_manager/features/autoscoring/data/autoscore_diagnostic_export.dart';

void main() {
  const previewFont = String.fromEnvironment('LAYOUT_PREVIEW_FONT');
  setUpAll(() async {
    if (previewFont.isNotEmpty) {
      await (FontLoader('Roboto')..addFont(
            Future.value(
              ByteData.sublistView(await File(previewFont).readAsBytes()),
            ),
          ))
          .load();
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    }
  });
  test(
    'A missing impact receives a ground truth point while detection remains missing',
    () {
      final c = AutoscoreDemoController();
      addTearDown(c.dispose);
      c.add(
        AutoscoringController.unresolvedThrow,
        evidence: AutoscoreEvidence([], {'manualMissingReport': true}),
      );
      c.movePoint(0, const Point(0, -103));
      expect(c.history.single.detectedPoint, isNull);
      expect(c.history.single.detected.label, 'Nicht erkannt');
      expect(c.history.single.correctedPoint, const Point(0.0, -103.0));
      expect(c.history.single.result.label, 'T20');
      expect(c.totalPoints, 60);
      expect(c.accuracyPercent, 0);
      c.reset();
      expect(c.history.single.correctedPoint, const Point(0.0, -103.0));
    },
  );
  for (final size in [
    const Size(360, 800),
    const Size(800, 600),
    const Size(1440, 900),
  ]) {
    testWidgets('Place missing point at $size with large text', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(tester.view.reset);
      Point<double>? result;
      final boundary = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () async {
                    result = await showDialog<Point<double>>(
                      context: context,
                      builder: (_) => const DartPositionDialog(cameras: []),
                    );
                  },
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Position speichern'),
            )
            .onPressed,
        isNull,
      );
      final surface = find.byKey(const ValueKey('flat-board-surface'));
      await tester.ensureVisible(surface);
      await tester.pumpAndSettle();
      final rect = tester.getRect(surface);
      await tester.tapAt(Offset(rect.center.dx, rect.top + rect.height * .25));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      if (previewFont.isNotEmpty) {
        final render =
            boundary.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        await tester.runAsync(() async {
          final image = await render.toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final file = File(
            'build/layout_previews/missing_point_${size.width.toInt()}.png',
          );
          await file.parent.create(recursive: true);
          await file.writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
      await tester.tap(find.text('Position speichern'));
      await tester.pumpAndSettle();
      expect(result, isNotNull);
      expect(result!.x, closeTo(0, .1));
      expect(result!.y, closeTo(-120, .1));
      expect(tester.takeException(), isNull);
    });
  }
}
