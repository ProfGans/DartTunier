import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_tournament_manager/features/tournaments/domain/tournament_format_planner.dart';
import 'package:dart_tournament_manager/features/tournaments/domain/tournament_models.dart';
import 'package:dart_tournament_manager/features/tournaments/presentation/widgets/planning_suggestion_list.dart';
import 'package:dart_tournament_manager/features/tournaments/presentation/widgets/planning_suggestion_card.dart';
import 'package:dart_tournament_manager/features/tournaments/application/expanded_format_planner.dart';

void main() {
  test(
    'full results retain ranking and include more than the first page',
    () async {
      const planner = ExpandedFormatPlanner();
      const request = TournamentPlanningRequest(
        players: 8,
        boards: 2,
        minimumMatchesPerPlayer: 1,
        minimumMinutes: 0,
        maximumMinutes: 10000,
        x01Selection: '501',
        checkoutType: 'double_out',
        maximumStages: 1,
      );
      final first = await planner.suggest(request);
      final all = await planner.suggest(request, allResults: true);
      expect(all.length, greaterThan(first.length));
      expect(
        all.take(first.length).map((s) => s.title),
        first.map((s) => s.title),
      );
      expect(all.map((s) => s.title).toSet().length, all.length);
    },
  );
  for (final size in [
    const Size(360, 800),
    const Size(800, 600),
    const Size(1440, 900),
  ]) {
    testWidgets('more proposals append and reset at $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      var suggestions = List.generate(
        3,
        (i) => TournamentFormatSuggestion(
          title: 'Vorschlag $i',
          stages: const [
            PlannedStage(
              type: 'single_knockout',
              groupCount: 0,
              format: TournamentGameFormat(),
            ),
          ],
          minimumMatchesPerPlayer: 1,
          totalMatches: 7,
          estimatedMinutes: 100,
          effectiveBoards: 2,
          participantCount: 8,
        ),
      );
      TournamentFormatSuggestion? selected;
      Widget app() => MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(2)),
          child: child!,
        ),
        home: Scaffold(
          body: SingleChildScrollView(
            child: PlanningSuggestionList(
              suggestions: suggestions,
              pageSize: 1,
              onSelected: (s) => selected = s,
            ),
          ),
        ),
      );
      await tester.pumpWidget(app());
      expect(find.byType(PlanningSuggestionCard), findsOneWidget);
      final more = find.byKey(const ValueKey('planner-more-suggestions'));
      for (var i = 2; i <= 3; i++) {
        await tester.ensureVisible(more);
        await tester.pumpAndSettle();
        await tester.tap(more);
        await tester.pumpAndSettle();
        expect(find.byType(PlanningSuggestionCard), findsNWidgets(i));
      }
      expect(more, findsNothing);
      await tester.ensureVisible(find.text('Vorschlag 2'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Vorschlag 2'));
      expect(selected, same(suggestions.last));
      suggestions = [...suggestions];
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      expect(find.byType(PlanningSuggestionCard), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
