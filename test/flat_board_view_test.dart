import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:dart_tournament_manager/features/autoscoring/domain/board_geometry.dart';
import 'package:dart_tournament_manager/features/autoscoring/domain/flat_board_projection.dart';
import 'package:dart_tournament_manager/features/autoscoring/presentation/widgets/flat_board_view.dart';
import 'package:dart_tournament_manager/features/autoscoring/application/autoscore_demo_controller.dart';
import 'package:dart_tournament_manager/features/autoscoring/data/autoscore_diagnostic_export.dart';

void main() {
  for (final screenWidth in [360.0, 1440.0]) {
    testWidgets('Projected image and marker coincide at width $screenWidth', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(screenWidth, 900);
      addTearDown(tester.view.reset);
      final calibration = BoardCalibration(const [
        Point(.5, .1),
        Point(.9, .5),
        Point(.5, .9),
        Point(.1, .5),
      ]);
      final source = img.Image(width: 160, height: 160);
      img.fill(source, color: img.ColorRgb8(35, 35, 35));
      img.fillCircle(
        source,
        x: 80,
        y: 41,
        radius: 5,
        color: img.ColorRgb8(230, 10, 10),
      );
      final q = calibration.project(const Point(80 / 159, 41 / 159));
      final boundary = GlobalKey();
      await tester.runAsync(() async {
        await tester.pumpWidget(
          MaterialApp(
            home: RepaintBoundary(
              key: boundary,
              child: Scaffold(
                body: SingleChildScrollView(
                  child: FlatBoardView(
                    cameras: [
                      FlatBoardCamera(img.encodePng(source), calibration),
                    ],
                    markers: [FlatBoardMarker(0, q, '20')],
                    onMoved: (_, _) {},
                  ),
                ),
              ),
            ),
          ),
        );
        for (
          var attempt = 0;
          attempt < 50 && find.byType(Image).evaluate().isEmpty;
          attempt++
        ) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
          await tester.pump();
        }
        final image = tester.widget<Image>(find.byType(Image));
        await precacheImage(image.image, tester.element(find.byType(Image)));
        await tester.pump();
      });
      await tester.pumpAndSettle();
      expect(find.byType(Image), findsOneWidget);
      final markerCenter = tester.getCenter(
        find.byTooltip('Treffer 1 auswählen'),
      );
      await tester.runAsync(() async {
        final render =
            boundary.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        final picture = await render.toImage(pixelRatio: 1);
        final bytes = await picture.toByteData(format: ui.ImageByteFormat.png);
        picture.dispose();
        final screenshot = img.decodePng(bytes!.buffer.asUint8List())!;
        var minX = screenshot.width,
            maxX = 0,
            minY = screenshot.height,
            maxY = 0;
        for (final p in screenshot) {
          if (p.r > 180 && p.g < 40 && p.b < 40) {
            minX = min(minX, p.x);
            maxX = max(maxX, p.x);
            minY = min(minY, p.y);
            maxY = max(maxY, p.y);
          }
        }
        expect(maxX, greaterThan(minX));
        final imageCenter = Offset((minX + maxX) / 2, (minY + maxY) / 2);
        expect(
          (imageCenter - markerCenter).distance,
          lessThan(2),
          reason:
              'Image and markers must share the same scale, also above the 480px raster size.',
        );
        Directory('build/layout_previews').createSync(recursive: true);
        File(
          'build/layout_previews/flat_board_alignment_${screenWidth.toInt()}.png',
        ).writeAsBytesSync(bytes.buffer.asUint8List());
      });
      expect(tester.takeException(), isNull);
    });
  }
  test('All three views contribute to the same projected board plane', () {
    final calibration = BoardCalibration(const [
      Point(.5, .1),
      Point(.9, .5),
      Point(.5, .9),
      Point(.1, .5),
    ]);
    final cameras = [
      for (final color in [
        img.ColorRgb8(180, 0, 0),
        img.ColorRgb8(0, 180, 0),
        img.ColorRgb8(0, 0, 180),
      ])
        FlatBoardCamera(
          img.encodePng(
            img.fill(img.Image(width: 40, height: 40), color: color),
          ),
          calibration,
        ),
    ];
    final projected = img.decodePng(projectFlatBoard(cameras))!;
    final bull = projected.getPixel(240, 240);
    expect([bull.r, bull.g, bull.b], [60, 60, 60]);
    expect(projected.width, 480);
  });
  test(
    'Point correction preserves original, updates scoring and counts an error',
    () {
      final controller = AutoscoreDemoController();
      addTearDown(controller.dispose);
      controller.add(
        BoardGeometry.score(const Point(0, -103)),
        evidence: AutoscoreEvidence([], {
          'xMillimetres': 0.0,
          'yMillimetres': -103.0,
        }),
      );
      controller.movePoint(0, const Point(30, -130));
      expect(controller.history.first.detected.label, 'T20');
      expect(controller.history.first.detectedPoint, const Point(0.0, -103.0));
      expect(
        controller.history.first.correctedPoint,
        const Point(30.0, -130.0),
      );
      expect(controller.totalPoints, 1);
      expect(controller.accuracyPercent, 0);
      controller.reset();
      expect(controller.visitStart, 1);
      expect(controller.history.first.correctedPoint, isNotNull);
    },
  );
  for (final size in [
    const Size(360, 800),
    const Size(800, 600),
    const Size(1440, 900),
  ]) {
    testWidgets('Flat board drag at $size and 200% text', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(tester.view.reset);
      BoardPoint? moved;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MediaQuery(
              data: MediaQueryData(
                size: size,
                textScaler: const TextScaler.linear(2),
              ),
              child: SingleChildScrollView(
                child: FlatBoardView(
                  cameras: const [],
                  markers: const [FlatBoardMarker(0, Point(0, 0), 'Bull')],
                  onMoved: (_, point) => moved = point,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final marker = find.byTooltip('Treffer 1 auswählen');
      await tester.ensureVisible(marker);
      await tester.drag(marker, const Offset(60, 0));
      await tester.pumpAndSettle();
      expect(moved, isNotNull);
      expect(moved!.x, greaterThan(10));
      expect(tester.takeException(), isNull);
    });
  }
  test('Recorded cameras produce a flat image for visual inspection', () {
    const root = 'test/fixtures/autoscoring/corrections/case_67';
    final report = jsonDecode(File('$root/bericht.json').readAsStringSync());
    final bytes = projectFlatBoard([
      for (var i = 0; i < 3; i++)
        FlatBoardCamera(
          File('$root/kamera_${i + 1}_treffer.png').readAsBytesSync(),
          BoardCalibration([
            for (final p in report['cameras'][i]['calibration'])
              Point((p['x'] as num).toDouble(), (p['y'] as num).toDouble()),
          ]),
        ),
    ]);
    Directory('build/autoscore_analysis').createSync(recursive: true);
    File(
      'build/autoscore_analysis/flat_board_preview.png',
    ).writeAsBytesSync(bytes);
    expect(img.decodePng(bytes), isNotNull);
  });
}
