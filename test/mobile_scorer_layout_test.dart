import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_tournament_manager/app/app_theme.dart';
import 'package:dart_tournament_manager/features/scorer/presentation/scorer_match_page.dart';
import 'package:dart_tournament_manager/features/scorer/presentation/widgets/score_keypad.dart';
import 'package:dart_tournament_manager/features/scorer/domain/scorer_settings.dart';

void main() {
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
  testWidgets('mobile touch entry survives switching to desktop and rotation', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 800);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildDartTournamentTheme(),
        home: ScorerMatchPage(
          settings: ScorerSettings(
            participants: const [
              ScorerParticipant('Anna'),
              ScorerParticipant('Ben'),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    for (final digit in ['4', '1']) {
      await Scrollable.ensureVisible(
        tester.element(find.text(digit)),
        alignment: .5,
      );
      await tester.pump();
      final button = find.ancestor(
        of: find.text(digit),
        matching: find.byType(OutlinedButton),
      );
      expect(tester.getSize(button).width, greaterThanOrEqualTo(48));
      expect(tester.getSize(button).height, greaterThanOrEqualTo(48));
      await tester.tap(find.text(digit));
      await tester.pump();
    }
    final state = tester.state(find.byType(ScoreKeypad));
    for (final size in [
      const Size(1440, 900),
      const Size(800, 600),
      const Size(320, 568),
    ]) {
      tester.view.physicalSize = size;
      await tester.pumpAndSettle();
      expect(tester.state(find.byType(ScoreKeypad)), same(state));
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('score-display'))).data,
        '41',
      );
      expect(tester.takeException(), isNull);
    }
  });
  for (final size in [
    const Size(320, 568),
    const Size(360, 800),
    const Size(412, 892),
  ]) {
    testWidgets(
      'Both scores and complete calculator visible without scrolling at $size',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final boundary = GlobalKey();
        await tester.pumpWidget(
          MaterialApp(
            theme: buildDartTournamentTheme(),
            home: RepaintBoundary(
              key: boundary,
              child: ScorerMatchPage(
                settings: ScorerSettings(
                  bestOfLegs: 11,
                  participants: const [
                    ScorerParticipant('ProfGans'),
                    ScorerParticipant('Yannick'),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('ProfGans').hitTestable(), findsOneWidget);
        expect(find.text('Yannick').hitTestable(), findsOneWidget);
        for (final label in [
          '1',
          '2',
          '3',
          '4',
          '5',
          '6',
          '7',
          '8',
          '9',
          '0',
          'C',
          '180',
        ]) {
          expect(
            find.text(label).hitTestable(),
            findsOneWidget,
            reason: 'Visible $label',
          );
        }
        expect(
          tester.getRect(find.byType(ScoreKeypad)).bottom,
          lessThanOrEqualTo(size.height),
        );
        expect(find.textContaining('Heatmap-Ziel:'), findsNothing);
        expect(find.textContaining('ist am Wurf'), findsNothing);
        expect(
          find.textContaining('Summe der Aufnahme eingeben'),
          findsNothing,
        );
        if (font.isNotEmpty) {
          await tester.runAsync(() async {
            final render =
                boundary.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            final image = await render.toImage();
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            final file = File(
              'build/layout_previews/scorer_phone_complete_${size.width.toInt()}.png',
            );
            await file.parent.create(recursive: true);
            await file.writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
        await tester.tap(find.byTooltip('Schnellpunkte'));
        await tester.pumpAndSettle();
        expect(find.text('Überworfen'), findsOneWidget);
        await tester.tap(find.text('26'));
        await tester.pumpAndSettle();
        expect(find.text('475'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
