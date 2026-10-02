import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_tournament_manager/app/app_theme.dart';
import 'package:dart_tournament_manager/features/autoscoring/application/autoscoring_controller.dart';
import 'package:dart_tournament_manager/features/autoscoring/domain/automatic_board_calibration.dart';
import 'package:dart_tournament_manager/features/autoscoring/presentation/autoscoring_page.dart';
import 'package:dart_tournament_manager/features/autoscoring/presentation/widgets/camera_recognition_view.dart';

class _DiagnosticsController extends AutoscoringController {
  _DiagnosticsController() {
    for (var i = 1; i <= 3; i++) {
      final bytes = File(
        'test/fixtures/autoscoring/shifted_$i.png',
      ).readAsBytesSync();
      final diagnostics = detectBoardOutline(bytes).diagnostics!;
      cameras.add(
        AutoscoreCamera(
            CameraDescription(
              name: 'USB-Kamera $i',
              lensDirection: CameraLensDirection.external,
              sensorOrientation: 0,
            ),
            i,
            317 / 179,
          )
          ..snapshot = bytes
          ..diagnostics = diagnostics
          ..calibrationMessage = 'Ring-Vorschlag · nicht freigegeben',
      );
    }
    // A rejected candidate must remain inspectable without activating scoring.
    cameras[1].diagnostics = BoardDetectionDiagnostics(selectiveColors: false)
      ..colorSamples = cameras[1].diagnostics!.colorSamples
      ..colorCount = cameras[1].diagnostics!.colorCount
      ..bullCandidates = const [Point(.50, .40), Point(.53, .49)]
      ..stage = 'Bull-Erkennung';
    cameras[1].calibrationMessage = 'Bull nicht eindeutig erkannt.';
    status = 'Kalibrierung nicht vollständig. Erkennungsvorschläge prüfen.';
  }
  @override
  Future<void> discover() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const previewFont = String.fromEnvironment('LAYOUT_PREVIEW_FONT');
  setUpAll(() async {
    if (previewFont.isNotEmpty) {
      await (FontLoader('Roboto')..addFont(
            File(previewFont).readAsBytes().then(ByteData.sublistView),
          ))
          .load();
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    }
  });
  for (final size in [
    const Size(360, 800),
    const Size(800, 600),
    const Size(1440, 900),
  ]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('Rejected recognition overlays $size text $scale', (
        tester,
      ) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = size;
        addTearDown(tester.view.reset);
        final controller = _DiagnosticsController();
        final boundary = GlobalKey();
        await tester.pumpWidget(
          MaterialApp(
            theme: buildDartTournamentTheme(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: RepaintBoundary(
              key: boundary,
              child: AutoscoringPage(controller: controller),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.runAsync(() async {
          for (final camera in controller.cameras) {
            await precacheImage(
              MemoryImage(camera.snapshot!),
              boundary.currentContext!,
            );
          }
        });
        await tester.scrollUntilVisible(
          find.text('Erkannte Farbpixel zusätzlich anzeigen').hitTestable(),
          150,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(find.text('Erkannte Farbpixel zusätzlich anzeigen'));
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('camera-recognition-0')).hitTestable(),
          150,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        final painters = tester
            .widgetList<CustomPaint>(find.byType(CustomPaint))
            .map((w) => w.painter)
            .whereType<RecognitionOverlayPainter>()
            .toList();
        expect(painters, isNotEmpty);
        expect(
          painters.every((p) => p.calibration == null && p.showColorSamples),
          isTrue,
        );
        expect(controller.running, isFalse);
        expect(controller.throws, isEmpty);
        expect(tester.takeException(), isNull);
        if (previewFont.isNotEmpty && scale == 1) {
          await tester.runAsync(() async {
            final render =
                boundary.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            final picture = await render.toImage();
            final bytes = await picture.toByteData(
              format: ui.ImageByteFormat.png,
            );
            final file = File(
              'build/layout_previews/autoscoring_overlay_${size.width.toInt()}.png',
            );
            await file.parent.create(recursive: true);
            await file.writeAsBytes(bytes!.buffer.asUint8List());
            picture.dispose();
          });
        }
        tester
            .state<ScrollableState>(find.byType(Scrollable).first)
            .position
            .jumpTo(0);
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.text('Erkennung in Kamerabildern anzeigen').hitTestable(),
          150,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(find.text('Erkennung in Kamerabildern anzeigen'));
        await tester.pumpAndSettle();
        expect(
          tester
              .widgetList<CustomPaint>(find.byType(CustomPaint))
              .map((w) => w.painter)
              .whereType<RecognitionOverlayPainter>(),
          isEmpty,
        );
        expect(controller.running, isFalse);
        await tester.pumpWidget(const SizedBox());
        controller.cameras.clear();
        controller.dispose();
      });
    }
  }
}
