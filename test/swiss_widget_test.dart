import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:dart_tournament_manager/app/app_theme.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_tournament_manager/features/tournaments/domain/tournament_models.dart';
import 'package:dart_tournament_manager/features/tournaments/modes/swiss/swiss_engine.dart';
import 'package:dart_tournament_manager/features/tournaments/presentation/widgets/run/group_stage_run_section.dart';
import 'package:dart_tournament_manager/features/tournaments/presentation/widgets/creation/stage_setup_widgets.dart';

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
  ]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('Swiss setup and standings at $size, text $scale', (
        tester,
      ) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = size;
        addTearDown(tester.view.reset);
        final players = List.generate(
          7,
          (i) => TournamentPlayer.generated(i + 1),
        );
        final group = TournamentGroup(
          name: 'Swiss-Gruppe',
          playType: 'swiss',
          players: players,
          matches: SwissEngine.build(players, 3),
        );
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
              child: Scaffold(
                body: SingleChildScrollView(
                  child: Column(
                    children: [
                      RoundRobinRepeatsSetup(
                        groupSizes: const [7],
                        playTypes: const ['swiss'],
                        repeats: const [3],
                        onChangeRepeats: (_, _) {},
                      ),
                      GroupStageRunSection(
                        stage: GroupTournamentRunStage(
                          name: 'Swiss',
                          groupPlayType: 'swiss',
                          groups: [group],
                          qualificationPlan: null,
                          tieBreakers: const ['points'],
                        ),
                        standingsFor: (g, _) => SwissEngine.standings(g),
                        onEditResult: (_) {},
                        canEditResults: true,
                        miniKnockoutBracketBuilder: (_, _, _, _) =>
                            const SizedBox(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.textContaining('Nächste Runde erst'), findsOneWidget);
        expect(find.text('Buchholz', skipOffstage: false), findsOneWidget);
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
              'build/layout_previews/swiss_${size.width.toInt()}_$scale.png',
            );
            await file.parent.create(recursive: true);
            await file.writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
      });
    }
  }
}
