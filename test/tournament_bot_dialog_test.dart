import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_tournament_manager/features/tournaments/presentation/widgets/creation/tournament_bot_dialog.dart';
import 'package:dart_tournament_manager/features/tournaments/domain/tournament_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const font = String.fromEnvironment('LAYOUT_PREVIEW_FONT');
  setUpAll(() async {
    if (font.isNotEmpty) {
      await (FontLoader(
        'Roboto',
      )..addFont(File(font).readAsBytes().then(ByteData.sublistView))).load();
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
    testWidgets('batch Theo bots at $size and large text', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      List<TournamentPlayer>? result;
      final preview = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: preview,
          child: MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(2)),
              child: child!,
            ),
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  child: const Text('Öffnen'),
                  onPressed: () async {
                    result = await showDialog<List<TournamentPlayer>>(
                      context: context,
                      builder: (_) => const TournamentBotDialog(players: []),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Öffnen'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      final fields = find.byType(TextField);
      await tester.enterText(fields.at(1), '40');
      await tester.enterText(fields.at(2), '70');
      await tester.pumpAndSettle();
      if (font.isNotEmpty) {
        final boundary =
            preview.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        await tester.runAsync(() async {
          final image = await boundary.toImage();
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          await Directory('build/layout_previews').create(recursive: true);
          await File(
            'build/layout_previews/bots_${size.width.toInt()}.png',
          ).writeAsBytes(data!.buffer.asUint8List());
          image.dispose();
        });
      }
      await tester.tap(find.text('Hinzufügen'));
      await tester.pumpAndSettle();
      expect(result, hasLength(10));
      expect(
        result!.every(
          (p) => p.bot!.targetAverage >= 40 && p.bot!.targetAverage <= 70,
        ),
        isTrue,
      );
      expect(tester.takeException(), isNull);
    });
  }
}
