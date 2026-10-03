import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_tournament_manager/features/community_trends/domain/community_trends.dart';
import 'package:dart_tournament_manager/features/community_trends/presentation/community_trends_page.dart';
import 'package:dart_tournament_manager/features/communities/domain/community_statistics.dart';
import 'package:dart_tournament_manager/features/communities/presentation/community_statistics_page.dart';
import 'package:dart_tournament_manager/features/tournaments/domain/tournament_models.dart';
import 'community_tournament_elo_test.dart'
    show eloMembers, eloTournament, eloPlayers;

CommunityStatistics trendsFixture() {
  final t = eloTournament();
  final matches =
      (t.runStages.first as GroupTournamentRunStage).groups.first.matches;
  matches.clear();
  for (var i = 0; i < 10; i++) {
    final recent = i >= 5;
    matches.add(
      GroupMatch(
        homePlayer: eloPlayers[0],
        awayPlayer: eloPlayers[1],
        round: i + 1,
        homeLegs: recent ? 3 : 0,
        awayLegs: recent ? 0 : 3,
        finishedAt: DateTime(2026, recent ? 8 : 5, 1 + i),
      ),
    );
  }
  return CommunityStatistics(
    communityId: 'community',
    members: eloMembers,
    tournaments: [t, t],
  );
}

class CommunityTrendsPreview extends StatelessWidget {
  const CommunityTrendsPreview({super.key});
  @override
  Widget build(BuildContext context) => CommunityTrendsPage(
    communityName: 'Dartclub',
    data: trendsFixture(),
    now: DateTime(2026, 10, 3),
  );
}

void main() {
  test(
    'compares disjoint periods, deduplicates and classifies both directions',
    () {
      final trends = CommunityTrends(
        trendsFixture(),
        now: DateTime(2026, 10, 3),
      );
      final rising = trends.players.singleWhere(
        (p) => p.kind == CommunityTrendKind.rising,
      );
      expect(rising.player.id, 'a');
      expect(rising.change, 100);
      expect(rising.previous!.matches, 5);
      expect(rising.recent!.matches, 5);
      expect(
        trends.players
            .singleWhere((p) => p.kind == CommunityTrendKind.practice)
            .player
            .id,
        'b',
      );
      expect(trends.previousPeriod.contains(DateTime(2026, 7, 3)), isFalse);
      expect(trends.recentPeriod.contains(DateTime(2026, 7, 3)), isTrue);
      expect(trends.recentPeriod.contains(DateTime(2026, 10, 4)), isFalse);
      expect(
        DateUtilsForTrends.monthsBefore(DateTime(2026, 5, 31), 3),
        DateTime(2026, 2, 28),
      );
    },
  );
  test(
    'few results are insufficient, draws count half, corrections recalculate',
    () {
      final data = trendsFixture();
      final matches =
          (data.tournaments.first.runStages.first as GroupTournamentRunStage)
              .groups
              .first
              .matches;
      matches.last.isAnnulled = true;
      expect(
        CommunityTrends(
          data,
          now: DateTime(2026, 10, 3),
        ).players.every((p) => p.kind == CommunityTrendKind.insufficient),
        isTrue,
      );
      matches.last.isAnnulled = false;
      for (final m in matches) {
        m.homeLegs = 2;
        m.awayLegs = 2;
      }
      final stable = CommunityTrends(
        data,
        now: DateTime(2026, 10, 3),
      ).players.first;
      expect(stable.kind, CommunityTrendKind.stable);
      expect(CommunityPlayerTrend.rate(stable.recent), 50);
    },
  );
  testWidgets('statistics menu opens Trends', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CommunityStatisticsMenu(
            communityName: 'Dartclub',
            data: trendsFixture(),
          ),
        ),
      ),
    );
    await tester.scrollUntilVisible(find.text('Trends').hitTestable(), 150);
    await tester.tap(find.text('Trends'));
    await tester.pumpAndSettle();
    expect(find.byType(CommunityTrendsPage), findsOneWidget);
  });
  for (final size in [
    const Size(360, 800),
    const Size(800, 600),
    const Size(1440, 900),
  ]) {
    testWidgets('trends fit $size at 200 percent', (tester) async {
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
          home: const CommunityTrendsPreview(),
        ),
      );
      await tester.pumpAndSettle();
      for (var i = 0; i < 10; i++) {
        expect(tester.takeException(), isNull);
        await tester.drag(find.byType(Scrollable).first, const Offset(0, -350));
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull);
    });
  }
}
