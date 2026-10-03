import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_tournament_manager/features/communities/domain/community.dart';
import 'package:dart_tournament_manager/features/communities/domain/community_elo.dart';
import 'package:dart_tournament_manager/features/communities/domain/community_elo_records.dart';
import 'package:dart_tournament_manager/features/communities/presentation/community_ranking_history_page.dart';

void main() {
  final history = [
    for (final (delta, rating) in [(16, 1016), (-20, 996), (25, 1021)])
      CommunityEloHistoryItem(
        playedAt: DateTime(2026),
        tournamentName: 'Vereinsmeisterschaft',
        opponentName: 'Ein besonders langer Spielername',
        score: '3:1',
        delta: delta,
        ratingAfter: rating,
      ),
  ];
  test('records use the full trajectory including the initial rating', () {
    expect(CommunityEloRecords(history).peak, 1021);
    expect(CommunityEloRecords(history).largestGain, 25);
    expect(CommunityEloRecords([]).peak, 1000);
    expect(CommunityEloRecords([history[1]]).peak, 1000);
  });
  for (final size in [
    const Size(360, 800),
    const Size(800, 600),
    const Size(1440, 900),
  ]) {
    testWidgets('Elo overview $size with large text', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final entry =
          CommunityEloEntry(
              player: CommunityMember(
                userId: 'a',
                displayName: 'Anna',
                role: 'member',
                joinedAt: DateTime(2026),
              ),
              rating: 1021,
            )
            ..matches = 3
            ..wins = 2
            ..losses = 1;
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: CommunityRankingHistoryPage(
            entry: entry,
            history: history,
            currentYearOnly: false,
          ),
        ),
      );
      expect(find.text('Elo-Verlauf'), findsOneWidget);
      await tester.scrollUntilVisible(find.byType(Slider), 100);
      await tester.pumpAndSettle();
      tester.widget<Slider>(find.byType(Slider)).onChanged!(0);
      await tester.pumpAndSettle();
      expect(find.text('Startwert: 1000 Elo'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Höchster Elo-Wert: 1021'),
        150,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
