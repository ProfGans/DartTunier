import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_tournament_manager/features/communities/application/community_live_ranking.dart';
import 'package:dart_tournament_manager/features/communities/domain/community_ranking_action.dart';
import 'package:dart_tournament_manager/features/communities/presentation/widgets/community_live_ranking_view.dart';
import 'package:dart_tournament_manager/features/communities/presentation/widgets/community_tournament_elo_panel.dart';
import 'package:dart_tournament_manager/features/tournaments/domain/tournament_models.dart';
import 'community_tournament_elo_test.dart'
    show eloTournament, eloMembers, eloData;

CreatedTournament priorRankingTournament() => CreatedTournament.fromJson(
  eloTournament(completed: true).toJson()
    ..['id'] = 'prior'
    ..['createdAt'] = DateTime(2026, 1, 1).toIso8601String(),
);
CreatedTournament liveRankingTournament() {
  final t = CreatedTournament.fromJson(
    eloTournament().toJson()
      ..['createdAt'] = DateTime(2026, 1, 2).toIso8601String(),
  );
  final match =
      (t.runStages.first as GroupTournamentRunStage).groups.first.matches.first;
  match.homeLegs = 0;
  match.awayLegs = 3;
  return t;
}

List<CommunityLiveRankingEntry> liveRankingFixture() =>
    const CommunityLiveRanking().calculate(
      tournament: liveRankingTournament(),
      tournaments: [priorRankingTournament()],
      members: eloMembers,
      rankingId: 'default',
      currentYearOnly: false,
    );

class LiveRankingPreview extends StatelessWidget {
  const LiveRankingPreview({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Turnier · Live-Rangliste')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [CommunityLiveRankingView(entries: liveRankingFixture())],
    ),
  );
}

void main() {
  test(
    'rating and position changes compare with ranking excluding live tournament',
    () {
      final rows = liveRankingFixture();
      expect(rows.first.entry.player.playerProfileId, 'b');
      expect(rows.first.entry.rating, 1001);
      expect(rows.first.eloChange, 17);
      expect(rows.first.position, 1);
      expect(rows.first.previousPosition, 2);
      expect(rows.first.positionChange, 1);
      expect(rows.last.eloChange, -17);
      expect(rows.last.positionChange, -1);
      expect(rows.every((r) => r.participating), isTrue);
    },
  );
  test('new players, draws, shared places and corrections', () {
    final t = liveRankingTournament();
    final match = (t.runStages.first as GroupTournamentRunStage)
        .groups
        .first
        .matches
        .first;
    match.homeLegs = 2;
    match.awayLegs = 2;
    List<CommunityLiveRankingEntry> calculate() =>
        const CommunityLiveRanking().calculate(
          tournament: t,
          tournaments: [t],
          members: eloMembers,
          rankingId: 'default',
          currentYearOnly: false,
        );
    final rows = calculate();
    expect(rows.map((r) => r.position), [1, 1]);
    expect(
      rows.every((r) => r.previousPosition == null && r.eloChange == 0),
      isTrue,
    );
    match.homeLegs = null;
    match.awayLegs = null;
    expect(calculate(), isEmpty);
  });
  test(
    'saved copy is replaced; foreign communities and removed players are excluded',
    () {
      final t = liveRankingTournament();
      final foreign = CreatedTournament.fromJson(
        priorRankingTournament().toJson()
          ..['communityId'] = 'other'
          ..['id'] = 'foreign',
      );
      final rows = const CommunityLiveRanking().calculate(
        tournament: t,
        tournaments: [priorRankingTournament(), t, foreign],
        members: eloMembers,
        rankingId: 'default',
        currentYearOnly: false,
      );
      expect(rows.first.eloChange, 17);
      final removed = const CommunityLiveRanking().calculate(
        tournament: t,
        tournaments: [priorRankingTournament()],
        members: eloMembers,
        rankingId: 'default',
        currentYearOnly: false,
        actions: [
          CommunityRankingAction(
            id: 1,
            rankingId: 'default',
            playerKey: 'a',
            action: RankingPlayerAction.remove,
            createdAt: DateTime(2026, 1, 3),
          ),
        ],
      );
      expect(removed.map((r) => r.entry.player.playerProfileId), ['b']);
      expect(
        const CommunityLiveRanking().calculate(
          tournament: t,
          tournaments: [],
          members: eloMembers,
          rankingId: 'other',
          currentYearOnly: false,
        ),
        isEmpty,
      );
    },
  );
  testWidgets(
    'toggle updates immediately on result rebuild without loading again',
    (tester) async {
      final t = eloTournament();
      var loads = 0;
      late StateSetter rebuild;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                rebuild = setState;
                return ListView(
                  children: [
                    CommunityTournamentEloPanel(
                      tournament: t,
                      activeStage: 0,
                      load: () async {
                        loads++;
                        return eloData();
                      },
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Live-Rangliste anzeigen'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Live-Rangliste anzeigen'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<CommunityLiveRankingView>(
              find.byType(CommunityLiveRankingView),
            )
            .entries,
        isEmpty,
      );
      rebuild(() {
        final match = (t.runStages.first as GroupTournamentRunStage)
            .groups
            .first
            .matches
            .first;
        match.homeLegs = 3;
        match.awayLegs = 1;
      });
      await tester.pumpAndSettle();
      final rows = tester
          .widget<CommunityLiveRankingView>(
            find.byType(CommunityLiveRankingView),
          )
          .entries;
      expect(rows.first.entry.rating, 1016);
      expect(rows.first.eloChange, 16);
      expect(loads, 1);
      await tester.binding.setSurfaceSize(const Size(360, 800));
      await tester.pumpAndSettle();
      expect(find.byType(CommunityLiveRankingView), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.binding.setSurfaceSize(null);
    },
  );
  for (final size in [
    const Size(360, 800),
    const Size(800, 600),
    const Size(1440, 900),
  ]) {
    testWidgets('live ranking fits $size at large text', (tester) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: const LiveRankingPreview(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('1001 Elo · +17 Elo'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
