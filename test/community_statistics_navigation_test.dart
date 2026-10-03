import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_tournament_manager/features/communities/domain/community.dart';
import 'package:dart_tournament_manager/features/communities/domain/community_statistics.dart';
import 'package:dart_tournament_manager/features/communities/presentation/community_statistics_page.dart';
import 'package:dart_tournament_manager/features/communities/presentation/community_statistics_players_page.dart';
import 'package:dart_tournament_manager/features/communities/presentation/community_player_statistics_page.dart';
import 'package:dart_tournament_manager/features/tournaments/domain/tournament_models.dart';
import 'community_tournament_elo_test.dart' show eloMembers, eloTournament;

CommunityStatistics statisticsFixture() => CommunityStatistics(
  communityId: 'community',
  members: [
    ...eloMembers,
    CommunityMember(
      userId: 'idle',
      playerProfileId: 'idle',
      displayName: 'Carla ohne Spiele',
      role: 'member',
      joinedAt: DateTime(2026),
    ),
  ],
  tournaments: [eloTournament(completed: true)],
);

class CommunityStatisticsPreview extends StatelessWidget {
  const CommunityStatisticsPreview({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Statistik · Dartclub')),
    body: CommunityStatisticsMenu(
      communityName: 'Dartclub',
      data: statisticsFixture(),
    ),
  );
}

class CommunityPlayerStatisticsPreview extends StatelessWidget {
  const CommunityPlayerStatisticsPreview({super.key});
  @override
  Widget build(BuildContext context) {
    final data = statisticsFixture();
    return CommunityPlayerStatisticsPage(
      communityName: 'Dartclub',
      data: data,
      player: data.players.first,
    );
  }
}

void main() {
  test(
    'community isolation, idle players, aliases and duplicate tournaments',
    () {
      final original = eloTournament(completed: true);
      final foreign = CreatedTournament.fromJson(
        original.toJson()
          ..['communityId'] = 'other'
          ..['id'] = 'foreign',
      );
      final alias = CommunityMember(
        userId: 'new',
        playerProfileId: 'new',
        displayName: 'Alex aktuell',
        aliasProfileIds: const ['a'],
        role: 'member',
        joinedAt: DateTime(2026),
      );
      final data = CommunityStatistics(
        communityId: 'community',
        members: [alias, eloMembers.last],
        tournaments: [original, original, foreign],
      );
      expect(data.tournaments, hasLength(1));
      expect(data.players, hasLength(2));
      expect(data.players.first.name, 'Alex aktuell');
      expect(data.rows().firstWhere((r) => r.id == 'new').matches, 1);
      expect(statisticsFixture().players.map((p) => p.id), contains('idle'));
    },
  );
  testWidgets(
    'first category opens searchable player list and individual page',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: CommunityStatisticsPreview()),
      );
      expect(
        tester.getTopLeft(find.text('Spielerstatistiken')).dy,
        lessThan(tester.getTopLeft(find.text('Spielervergleich')).dy),
      );
      await tester.tap(find.text('Spielerstatistiken'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Carla');
      await tester.pumpAndSettle();
      expect(find.text('Benjamin'), findsNothing);
      await tester.tap(find.text('Carla ohne Spiele'));
      await tester.pumpAndSettle();
      expect(find.byType(CommunityPlayerStatisticsPage), findsOneWidget);
      expect(find.text('0 Turniere · 0 Spiele'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Carla'), findsOneWidget);
      expect(find.text('Benjamin'), findsNothing);
      await tester.enterText(find.byType(TextField), 'keine Treffer');
      await tester.pumpAndSettle();
      expect(find.text('Keine Spieler gefunden.'), findsOneWidget);
    },
  );
  testWidgets('comparison remains reachable', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: CommunityStatisticsPreview()),
    );
    await tester.tap(find.text('Spielervergleich'));
    await tester.pumpAndSettle();
    expect(find.text('Benjamin'), findsOneWidget);
    expect(find.text('1 Turniere · 1 Spiele'), findsNWidgets(2));
  });
  for (final size in [
    const Size(360, 800),
    const Size(800, 600),
    const Size(1440, 900),
  ]) {
    testWidgets('statistics navigation and filters at $size with large text', (
      tester,
    ) async {
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
          home: const CommunityStatisticsPreview(),
        ),
      );
      await tester.tap(find.text('Spielerstatistiken'));
      await tester.pumpAndSettle();
      expect(find.byType(CommunityStatisticsPlayersPage), findsOneWidget);
      await tester.tap(find.text(eloMembers.first.displayName));
      await tester.pumpAndSettle();
      expect(find.byType(CommunityPlayerStatisticsPage), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Dieses Jahr'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dieses Jahr'));
      await tester.pumpAndSettle();
      await tester.binding.setSurfaceSize(const Size(800, 600));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Dieses Jahr'))
            .selected,
        isTrue,
      );
      expect(tester.takeException(), isNull);
    });
  }
}
