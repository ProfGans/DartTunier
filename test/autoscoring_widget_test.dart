import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:dart_tournament_manager/app/app_theme.dart';
import 'package:dart_tournament_manager/features/autoscoring/application/autoscoring_controller.dart';
import 'package:dart_tournament_manager/features/autoscoring/domain/board_geometry.dart';
import 'package:dart_tournament_manager/features/autoscoring/presentation/autoscoring_page.dart';

class _PreviewController extends AutoscoringController {
  _PreviewController({bool connected = false}) {
    available = [
      for (var i = 0; i < 3; i++)
        CameraDescription(
          name: 'USB-Dartkamera ${i + 1}',
          lensDirection: CameraLensDirection.external,
          sensorOrientation: 0,
        ),
    ];
    if (connected) {
      final picture = img.Image(width: 320, height: 240);
      img.fill(picture, color: img.ColorRgb8(35, 40, 45));
      img.drawCircle(
        picture,
        x: 160,
        y: 120,
        radius: 90,
        color: img.ColorRgb8(220, 220, 210),
      );
      for (var i = 0; i < 3; i++) {
        cameras.add(
          AutoscoreCamera(available[i], i, 4 / 3)
            ..calibrationMessage =
                'Zahlenring mit automatisch gelernter Referenz abgeglichen · Board-Geometrie geprüft'
            ..snapshot = img.encodePng(picture)
            ..calibration = BoardCalibration(const [
              Point(.5, .1),
              Point(.9, .5),
              Point(.5, .9),
              Point(.1, .5),
            ]),
        );
      }
      pending = const FusedHit(Point(0, -103), 0, 3);
      status = 'Treffer erkannt. Prüfen und übernehmen.';
    }
  }
  @override
  Future<void> discover() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'USB cameras are selected by default and manual choices survive discovery',
    (tester) async {
      final controller = _PreviewController();
      controller.available.insert(
        0,
        const CameraDescription(
          name: 'Integrated Camera',
          lensDirection: CameraLensDirection.external,
          sensorOrientation: 0,
        ),
      );
      await tester.pumpWidget(
        MaterialApp(home: AutoscoringPage(controller: controller)),
      );
      await tester.pumpAndSettle();
      List<int?> values() => tester
          .widgetList<DropdownButtonFormField<int>>(
            find.byType(DropdownButtonFormField<int>),
          )
          .map((field) => field.initialValue)
          .toList();
      expect(values(), [1, 2, 3]);
      // Manual choice must not be overwritten by a subsequent search.
      tester
          .widgetList<DropdownButtonFormField<int>>(
            find.byType(DropdownButtonFormField<int>),
          )
          .first
          .onChanged!(0);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Kameras suchen'));
      await tester.tap(find.text('Kameras suchen'));
      await tester.pumpAndSettle();
      expect(values(), [0, 2, 3]);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    },
  );
  const previewFont = String.fromEnvironment('LAYOUT_PREVIEW_FONT');
  setUpAll(() async {
    if (previewFont.isNotEmpty) {
      await (FontLoader('Roboto')..addFont(
            File(
              previewFont,
            ).readAsBytes().then((b) => ByteData.sublistView(b)),
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
      for (final connected in [false, true]) {
        testWidgets('Autoscorer $size text $scale connected $connected', (
          tester,
        ) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = size;
          addTearDown(tester.view.reset);
          final controller = _PreviewController(connected: connected);
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
          if (connected) {
            await tester.runAsync(() async {
              for (final camera in controller.cameras) {
                await precacheImage(
                  MemoryImage(camera.snapshot!),
                  boundary.currentContext!,
                );
              }
            });
            await tester.pumpAndSettle();
          }
          expect(tester.takeException(), isNull);
          if (previewFont.isNotEmpty && scale == 1) {
            final render =
                boundary.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            await tester.runAsync(() async {
              final image = await render.toImage();
              final bytes = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              final file = File(
                'build/layout_previews/autoscoring_${size.width.toInt()}_${connected ? 'connected' : 'setup'}.png',
              );
              await file.parent.create(recursive: true);
              await file.writeAsBytes(bytes!.buffer.asUint8List());
              image.dispose();
            });
          }
          if (connected) {
            await tester.scrollUntilVisible(
              find.text('Treffer korrigieren'),
              300,
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            await tester.tap(find.text('Treffer korrigieren'));
            await tester.pumpAndSettle();
            expect(find.text('Treffer korrigieren'), findsNWidgets(2));
            expect(tester.takeException(), isNull);
          }
          await tester.pumpWidget(const SizedBox());
          controller.cameras.clear();
          controller.dispose();
          await tester.pumpAndSettle();
        });
      }
    }
  }
}
