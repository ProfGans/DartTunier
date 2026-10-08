import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_tournament_manager/features/autoscoring/application/autoscore_demo_controller.dart';
import 'package:dart_tournament_manager/features/autoscoring/data/autoscore_diagnostic_export.dart';
import 'package:dart_tournament_manager/features/autoscoring/presentation/widgets/autoscore_validation_panel.dart';
import 'package:dart_tournament_manager/features/autoscoring/presentation/widgets/contact_image_label_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final font = File('C:/Windows/Fonts/segoeui.ttf');
    if (font.existsSync()) {
      final loader = FontLoader('Roboto')
        ..addFont(Future.value(ByteData.sublistView(font.readAsBytesSync())));
      await loader.load();
    }
  });
  for (final size in [
    const Size(360, 800),
    const Size(800, 600),
    const Size(1440, 900),
  ]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('Collection and image labels at $size, text $scale', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final demo = AutoscoreDemoController();
        final boundary = GlobalKey();
        final evidence = AutoscoreEvidence([
          AutoscoreCameraEvidence(
            File(
              'test/fixtures/autoscoring/new_video/case_27/kamera_1_sequenz_8.png',
            ).readAsBytesSync(),
            null,
            null,
            {'camera': 1},
          ),
        ], {});
        await tester.pumpWidget(
          RepaintBoundary(
            key: boundary,
            child: MaterialApp(
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: Scaffold(
                body: SingleChildScrollView(
                  child: Column(
                    children: [
                      AutoscoreValidationPanel(controller: demo),
                      Builder(
                        builder: (context) => TextButton(
                          onPressed: () => showDialog(
                            context: context,
                            builder: (_) =>
                                ContactImageLabelDialog(evidence: evidence),
                          ),
                          child: const Text('Bild prüfen'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(
          find.text('Prüfserie: richtige und falsche Würfe sammeln'),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(find.text('Bild prüfen'));
        await tester.tap(find.text('Bild prüfen'));
        await tester.pumpAndSettle();
        await tester.runAsync(
          () => precacheImage(
            MemoryImage(evidence.cameras.first.image),
            boundary.currentContext!,
          ),
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byType(Image));
        await tester.pumpAndSettle();
        final canvas = find.byKey(const ValueKey('contact-image-gesture'));
        expect(
          tester.getSize(canvas).width,
          closeTo((size.width - 64).clamp(1, 800), .1),
        );
        await tester.tapAt(tester.getCenter(canvas));
        await tester.pump();
        final marker = find.byIcon(Icons.add_circle);
        expect(
          (tester.getTopLeft(marker) - tester.getCenter(canvas)).distance,
          closeTo(11.3137, .1),
        );
        if (size.width == 360 || size.width == 1440) {
          await tester.runAsync(() async {
            final image =
                await (boundary.currentContext!.findRenderObject()
                        as RenderRepaintBoundary)
                    .toImage();
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            final file = File(
              'build/autoscore_analysis/training_labels_${size.width.toInt()}_${scale.toInt()}.png',
            );
            await file.parent.create(recursive: true);
            await file.writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('Abbrechen'));
        await tester.pumpAndSettle();
        await tester.pumpWidget(const SizedBox());
        demo.dispose();
      });
    }
  }
}
