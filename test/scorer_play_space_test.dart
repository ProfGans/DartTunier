import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_tournament_manager/app/app_theme.dart';
import 'package:dart_tournament_manager/features/scorer/domain/scorer_settings.dart';
import 'package:dart_tournament_manager/features/scorer/presentation/widgets/scorer_play_layout.dart';
import 'package:dart_tournament_manager/features/scorer/presentation/widgets/scorer_scoreboard.dart';
import 'package:dart_tournament_manager/features/scorer/presentation/widgets/scorer_leg_sheet.dart';
import 'package:dart_tournament_manager/features/scorer/presentation/widgets/score_keypad.dart';

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
  for (final size in [
    const Size(360, 800),
    const Size(800, 600),
    const Size(1440, 900),
    const Size(2537, 1301),
  ]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('Scorer uses available playing height at $size text $scale', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final boundary = GlobalKey();
        final settings = ScorerSettings(
          participants: const [
            ScorerParticipant('Spieler 1'),
            ScorerParticipant('Spieler 2'),
          ],
        );
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
              child: Scaffold(
                body: SafeArea(
                  child: ScorerPlayLayout(
                    toolbar: const Text('501 · Double Out · Best of 3 Legs'),
                    board: const ScorerScoreboard(
                      players: [
                        ScorerScoreboardPlayer(
                          name: 'Spieler 1',
                          score: 501,
                          legs: 0,
                          sets: 0,
                          average: null,
                          active: true,
                          bot: false,
                        ),
                        ScorerScoreboardPlayer(
                          name: 'Spieler 2',
                          score: 501,
                          legs: 0,
                          sets: 0,
                          average: null,
                          active: false,
                          bot: false,
                        ),
                      ],
                    ),
                    input: Column(
                      children: [
                        ScoreKeypad(
                          enabled: true,
                          remaining: 501,
                          onSubmit: (_) async => true,
                          onBust: () {},
                        ),
                        const Text(
                          'Summe der Aufnahme eingeben und mit OK bestätigen.\nTastatur: Ziffern, Enter, Rücktaste, Esc.',
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                    history: ScorerLegSheet(
                      settings: settings,
                      visits: const [],
                      leg: 0,
                      starter: 0,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        if (size.width >= 1000 && scale == 1) {
          expect(
            tester.getSize(find.byType(ScorerScoreboard)).height,
            greaterThanOrEqualTo(size.height * .50),
          );
          expect(
            tester.getSize(find.widgetWithText(OutlinedButton, '1')).height,
            greaterThanOrEqualTo(size.height * .13),
          );
          expect(
            find.text('Schreibertafel · Leg 1').hitTestable(),
            findsOneWidget,
          );
        }
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
              'build/layout_previews/scorer_space_${size.width.toInt()}_$scale.png',
            );
            await file.parent.create(recursive: true);
            await file.writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
        final one = find.widgetWithText(OutlinedButton, '1');
        await tester.ensureVisible(one);
        await tester.tap(one);
        await tester.pump();
        expect(find.text('1'), findsNWidgets(2));
        tester.view.physicalSize = size.width >= 1000
            ? const Size(360, 800)
            : const Size(1440, 900);
        await tester.pumpAndSettle();
        expect(find.text('1'), findsNWidgets(2));
        expect(tester.takeException(), isNull);
      });
    }
  }
}
