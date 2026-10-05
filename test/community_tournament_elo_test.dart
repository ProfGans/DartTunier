import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_tournament_manager/features/communities/domain/community.dart';
import 'package:dart_tournament_manager/features/communities/domain/community_elo.dart';
import 'package:dart_tournament_manager/features/communities/domain/community_ranking.dart';
import 'package:dart_tournament_manager/features/communities/application/community_tournament_elo.dart';
import 'package:dart_tournament_manager/features/communities/presentation/widgets/community_tournament_elo_panel.dart';
import 'package:dart_tournament_manager/features/tournaments/domain/tournament_models.dart';

const eloPlayers = [
  TournamentPlayer(
    profileId: 'a',
    name: 'Alexandra mit langem Spielernamen',
    isGenerated: false,
  ),
  TournamentPlayer(profileId: 'b', name: 'Benjamin', isGenerated: false),
];
final eloMembers = [
  for (final p in eloPlayers)
    CommunityMember(
      userId: p.profileId,
      playerProfileId: p.profileId,
      displayName: p.name,
      role: 'member',
      joinedAt: DateTime(2026),
    ),
];

CreatedTournament eloTournament({bool completed = false}) => CreatedTournament(
  id: 'live',
  communityId: 'community',
  name: 'Elo-Test',
  players: eloPlayers,
  createdAt: DateTime(2026),
  stages: const [
    TournamentStage(
      name: 'Gruppe',
      type: 'groups',
      gameFormat: TournamentGameFormat(bestOfLegs: 4),
    ),
  ],
  runStages: [
    GroupTournamentRunStage(
      name: 'Gruppe',
      groupPlayType: 'round_robin',
      qualificationPlan: null,
      tieBreakers: const [],
      groups: [
        TournamentGroup(
          name: 'A',
          playType: 'round_robin',
          players: eloPlayers,
          matches: [
            GroupMatch(
              homePlayer: eloPlayers[0],
              awayPlayer: eloPlayers[1],
              round: 1,
              homeLegs: completed ? 3 : null,
              awayLegs: completed ? 1 : null,
            ),
            GroupMatch(
              homePlayer: eloPlayers[0],
              awayPlayer: eloPlayers[1],
              round: 2,
            ),
          ],
        ),
      ],
    ),
  ],
);

TournamentEloData eloData({bool enabled = true}) => TournamentEloData(
  enabled: enabled,
  members: eloMembers,
  tournaments: [],
  rankings: const [CommunityRanking.standard],
);

class TournamentEloPreview extends StatelessWidget {
  const TournamentEloPreview({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: ListView(
        children: [
          CommunityTournamentEloPanel(
            tournament: eloTournament(),
            activeStage: 0,
            load: () async => eloData(),
          ),
        ],
      ),
    ),
  );
}

void main() {
  List<TournamentEloPlayer> calculate(
    CreatedTournament t, {
    List<CreatedTournament> saved = const [],
    List<CommunityMember>? members,
    String ranking = 'default',
  }) => const CommunityTournamentElo().calculate(
    tournament: t,
    tournaments: saved,
    members: members ?? eloMembers,
    rankingId: ranking,
    currentYearOnly: true,
    activeStage: 0,
    now: DateTime(2026),
  );

  test('new players preview wins, losses, draws using ranking formula', () {
    final result = calculate(eloTournament());
    expect(result.map((p) => p.rating), [1000, 1000]);
    expect(result.map((p) => p.win), [16, 16]);
    expect(result.map((p) => p.loss), [-16, -16]);
    expect(result.map((p) => p.draw), [0, 0]);
  });
  test('live results replace saved copy and corrections recompute', () {
    final t = eloTournament(completed: true);
    final result = calculate(t, saved: [eloTournament(completed: true)]);
    expect(result.map((p) => p.rating), [1016, 984]);
    expect(result.first.win, communityEloDelta(1016, 984, 1));
    expect(result.first.win, -result.last.loss!);
    expect(result.first.draw, -result.last.draw!);
    expect(calculate(eloTournament(), saved: [t]).first.rating, 1000);
  });
  test(
    'ranking and community isolation, unknown players, alias resolution',
    () {
      final t = eloTournament();
      expect(calculate(t, ranking: 'other'), isEmpty);
      final foreign = CreatedTournament.fromJson(
        eloTournament(completed: true).toJson()
          ..['id'] = 'foreign'
          ..['communityId'] = 'elsewhere',
      );
      expect(calculate(t, saved: [foreign]).first.rating, 1000);
      expect(calculate(t, members: [eloMembers.first]).last.rating, isNull);
      expect(calculate(t, members: [eloMembers.first]).first.win, isNull);
      final alias = CommunityMember(
        userId: 'new',
        playerProfileId: 'new',
        aliasProfileIds: const ['a'],
        displayName: 'Alex',
        role: 'member',
        joinedAt: DateTime(2026),
      );
      expect(
        calculate(
          eloTournament(completed: true),
          members: [alias, eloMembers.last],
        ).first.rating,
        1016,
      );
      final unranked = CreatedTournament.fromJson(
        t.toJson()..['countsForRanking'] = false,
      );
      expect(calculate(unranked), isEmpty);
    },
  );
  test('completed games have no forecast and odd formats have no draw', () {
    final t = eloTournament(completed: true);
    final stage = t.runStages.first as GroupTournamentRunStage;
    stage.groups.first.matches.removeLast();
    expect(calculate(t).first.win, isNull);
    final odd = CreatedTournament.fromJson(
      eloTournament().toJson()
        ..['stages'] = [
          const TournamentStage(
            name: 'Odd',
            type: 'groups',
            gameFormat: TournamentGameFormat(bestOfLegs: 3),
          ).toJson(),
        ],
    );
    expect(calculate(odd).first.draw, isNull);
  });
  for (final size in [
    const Size(360, 800),
    const Size(800, 600),
    const Size(1440, 900),
  ]) {
    testWidgets('Elo preview fits $size at 200 percent', (tester) async {
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
          home: const TournamentEloPreview(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('· 1000 Elo'), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('collapsed Elo stays collapsed after scrolling out of view', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var loads = 0;
    final tournament = eloTournament();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CustomScrollView(
            cacheExtent: 0,
            slivers: [
              SliverList.list(
                children: [
                  CommunityTournamentEloPanel(
                    tournament: tournament,
                    activeStage: 0,
                    load: () async {
                      loads++;
                      return eloData();
                    },
                  ),
                  for (var i = 0; i < 20; i++)
                    SizedBox(height: 200, child: Text('Spiel $i')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Spieler · Elo und nächstes Spiel'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -1800));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(CustomScrollView), const Offset(0, 2500));
    await tester.pumpAndSettle();
    expect(
      find.text('Spieler · Elo und nächstes Spiel').hitTestable(),
      findsOneWidget,
    );
    expect(find.text('Elo aktualisieren').hitTestable(), findsNothing);
    expect(loads, 1);
    await tester.tap(find.text('Spieler · Elo und nächstes Spiel'));
    await tester.pumpAndSettle();
    expect(find.text('Elo aktualisieren').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('disabled ranking hides panel and errors allow retry', (
    tester,
  ) async {
    var fail = true;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [
              CommunityTournamentEloPanel(
                tournament: eloTournament(),
                activeStage: 0,
                load: () async {
                  if (fail) throw StateError('offline');
                  return eloData(enabled: false);
                },
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('konnte nicht geladen'), findsOneWidget);
    fail = false;
    await tester.tap(find.text('Elo aktualisieren'));
    await tester.pumpAndSettle();
    expect(find.text('Spieler · Elo und nächstes Spiel'), findsNothing);
  });
}
