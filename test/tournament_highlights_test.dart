import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:dart_tournament_manager/app/app_theme.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_tournament_manager/features/statistics/domain/match_scorer_summary.dart';
import 'package:dart_tournament_manager/features/statistics/domain/saved_scorer_match.dart';
import 'package:dart_tournament_manager/features/statistics/presentation/tournament_highlights_page.dart';
import 'package:dart_tournament_manager/features/scorer/domain/scorer_statistics.dart';
import 'package:dart_tournament_manager/features/tournaments/domain/tournament_models.dart';
import 'package:dart_tournament_manager/features/tournaments/presentation/widgets/run/result_entry.dart';

GroupMatch recordedMatch({int points = 120, int darts = 3}) =>
    GroupMatch(
        homePlayer: const TournamentPlayer(
          name: 'Anna Musterfrau',
          profileId: 'a',
          isGenerated: false,
        ),
        awayPlayer: const TournamentPlayer(
          name: 'Ben Beispielmann',
          profileId: 'b',
          isGenerated: false,
        ),
        round: 1,
      )
      ..homeLegs = 1
      ..awayLegs = 0
      ..deviceResult = {
        'statistics': SavedScorerMatch(
          id: 'm',
          accountId: '',
          playedAt: DateTime.utc(2026),
          playerIndex: 0,
          names: ['Anna Musterfrau', 'Ben Beispielmann'],
          startScores: [301, 301],
          standard501Rules: false,
          doubleOut: true,
          winner: 0,
          visits: [
            ScorerVisit(
              player: 0,
              leg: 0,
              starter: 0,
              points: points,
              darts: darts,
              remaining: 0,
              bust: false,
              checkoutAttempts: 1,
            ),
          ],
        ).toJson(),
      };

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
  test('weighted averages, missing stats, corrections and saved results', () {
    final first = recordedMatch(), second = recordedMatch(points: 60, darts: 1);
    final restored = GroupMatch.fromJson(first.toJson());
    final data = TournamentScorerHighlights([restored, second, second]);
    expect(data.recorded, 2);
    expect(data.players.single.average, 135); // 180 points / 4 darts * 3
    expect(data.players.single.highestFinish, 120);
    expect(data.players.single.bestLeg, 1);
    second.deviceResult = null;
    expect(TournamentScorerHighlights([restored, second]).recorded, 1);
    restored.homeLegs = null;
    restored.awayLegs = null;
    expect(MatchScorerSummary.fromMatch(restored), isNull);
    expect(TournamentScorerHighlights([restored, second]).players, isEmpty);
  });
  for (final size in [
    const Size(360, 800),
    const Size(800, 600),
    const Size(1440, 900),
  ]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('highlights and match average at $size / $scale', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final match = recordedMatch();
        final tournament = CreatedTournament(
          name: 'Herbstturnier',
          players: [],
          stages: [],
          runStages: [
            KnockoutTournamentRunStage(
              name: 'Finale',
              rounds: [
                [match],
              ],
            ),
          ],
        );
        final key = GlobalKey();
        Widget app(Widget page) => MaterialApp(
          theme: buildDartTournamentTheme(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: RepaintBoundary(key: key, child: page),
        );
        await tester.pumpWidget(
          app(TournamentHighlightsPage(tournament: tournament)),
        );
        await tester.pumpAndSettle();
        expect(find.text('Höchster Turnier-Average'), findsOneWidget);
        expect(
          find.text('1 abgeschlossene Spiele · 1 mit Scorer-Statistik'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        if (Platform.environment['RENDER_HIGHLIGHTS'] == '1' && scale == 1) {
          final boundary =
              key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
          await tester.runAsync(() async {
            final image = await boundary.toImage();
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await Directory('build/layout_previews').create(recursive: true);
            await File(
              'build/layout_previews/highlights_${size.width.toInt()}.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
        await tester.pumpWidget(
          app(
            Scaffold(
              body: SingleChildScrollView(
                child: MatchResultTile(
                  match: match,
                  canEditResult: false,
                  onEditResult: (_) {},
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Anna Musterfrau · Avg 120.00'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
