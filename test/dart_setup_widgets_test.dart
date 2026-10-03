import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_tournament_manager/features/personal_profile/domain/dart_setup.dart';
import 'package:dart_tournament_manager/features/personal_profile/presentation/dart_setup_widgets.dart';
import 'package:dart_tournament_manager/shared/widgets/adaptive_content.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const font = String.fromEnvironment('LAYOUT_PREVIEW_FONT');
  setUpAll(() async {
    if (font.isNotEmpty) {
      await (FontLoader('Roboto')..addFont(
            File(
              font,
            ).readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
          ))
          .load();
    }
  });
  for (final size in [const Size(360, 800), const Size(1440, 900)]) {
    testWidgets('Dart setup preview $size retains edits when resized', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var edited = const DartSetup(
        barrel: 'Target Beispiel',
        weight: '23 g',
        shaft: 'Nylon Short',
        flights: 'Standard No. 2',
        points: 'Steel 35 mm',
      );
      await tester.pumpWidget(
        RepaintBoundary(
          key: const ValueKey('preview'),
          child: MaterialApp(
            home: Scaffold(
              appBar: AppBar(title: const Text('Mein Profil')),
              body: AdaptiveContentList(
                maxWidth: 900,
                children: [
                  DartSetupFields(
                    initialValue: edited,
                    enabled: true,
                    onChanged: (value) => edited = value,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('dart-setup-field-0')),
        'Mein individuelles Dart-Setup',
      );
      expect(edited.barrel, 'Mein individuelles Dart-Setup');
      if (font.isNotEmpty) {
        await tester.runAsync(() async {
          final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(const ValueKey('preview')),
          );
          final image = await boundary.toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          image.dispose();
          final directory = Directory('build/layout_previews')
            ..createSync(recursive: true);
          await File(
            '${directory.path}/dart_setup_${size.width.toInt()}.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
        });
      }
      tester.view.physicalSize = size.width < 600
          ? const Size(1440, 900)
          : const Size(360, 800);
      await tester.pumpAndSettle();
      expect(find.text('Mein individuelles Dart-Setup'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
