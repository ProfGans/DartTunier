import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_tournament_manager/features/tournaments/domain/tournament_models.dart';
import 'package:dart_tournament_manager/features/tournaments/presentation/pages/tournament_results_page.dart';
import 'package:dart_tournament_manager/features/tournaments/presentation/widgets/results/tournament_results_statistics.dart';
import 'package:dart_tournament_manager/shared/widgets/adaptive_content.dart';
import 'tournament_highlights_test.dart' show recordedMatch;

CreatedTournament resultsFixture({bool recorded = true}) {
  final match = recordedMatch();
  if (!recorded) match.deviceResult = null;
  return CreatedTournament(
    name: 'Vereinsmeisterschaft',
    players: [match.homePlayer!, match.awayPlayer!],
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
}

class ResultsStatisticsPreview extends StatelessWidget {
  const ResultsStatisticsPreview({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    body: AdaptiveContentList(
      children: [TournamentResultsStatistics(tournament: resultsFixture())],
    ),
  );
}

void main() {
  testWidgets('results show highlights and player statistics inline', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: TournamentResultsPage(tournament: resultsFixture())),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Höchstes Checkout'), 200);
    expect(find.text('120'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Spielerstatistiken'), 200);
    await tester.scrollUntilVisible(
      find.textContaining('Average: 120.00'),
      150,
    );
    expect(find.textContaining('Checkout: 100.0 %'), findsOneWidget);
    expect(find.byType(TournamentResultsPage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'manual results retain player stats without invented scorer highlights',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdaptiveContentList(
              children: [
                TournamentResultsStatistics(
                  tournament: resultsFixture(recorded: false),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Noch nicht erfasst'), findsNWidgets(4));
      expect(
        find.text('1 abgeschlossene Spiele · 0 mit Scorer-Statistik'),
        findsOneWidget,
      );
      await tester.scrollUntilVisible(
        find.text('1 Siege · 0 Unentschieden · 0 Niederlagen'),
        150,
      );
      expect(find.textContaining('Average: '), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  for (final size in [
    const Size(360, 800),
    const Size(800, 600),
    const Size(1440, 900),
  ]) {
    testWidgets('results statistics at $size with 200 percent text', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: TournamentResultsPage(tournament: resultsFixture()),
        ),
      );
      await tester.pumpAndSettle();
      for (var i = 0; i < 14; i++) {
        expect(tester.takeException(), isNull);
        await tester.drag(find.byType(Scrollable).first, const Offset(0, -450));
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull);
    });
  }
}
