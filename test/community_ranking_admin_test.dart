import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_tournament_manager/features/communities/domain/community.dart';
import 'package:dart_tournament_manager/features/communities/domain/community_elo.dart';
import 'package:dart_tournament_manager/features/communities/domain/community_ranking_action.dart';
import 'package:dart_tournament_manager/features/communities/application/community_tournament_elo.dart';
import 'package:dart_tournament_manager/features/communities/presentation/community_ranking_page.dart';
import 'package:dart_tournament_manager/features/tournaments/domain/tournament_models.dart';
import 'community_tournament_elo_test.dart' show eloTournament, eloMembers;
import 'community_rankings_test.dart' show RankingsRepository;

CommunityRankingAction action(
  int day,
  RankingPlayerAction value, {
  String player = 'a',
  String ranking = 'default',
}) => CommunityRankingAction(
  id: day,
  rankingId: ranking,
  playerKey: player,
  action: value,
  createdAt: DateTime(2026, 1, day),
);

CreatedTournament completedOn(int day) {
  final tournament = eloTournament(completed: true);
  final matches = (tournament.runStages.first as GroupTournamentRunStage)
      .groups
      .first
      .matches;
  matches.removeLast();
  matches.first.finishedAt = DateTime(2026, 1, day);
  // Each day represents a distinct tournament, not another copy of 'live'.
  return CreatedTournament.fromJson({...tournament.toJson(), 'id': 'day-$day'});
}

class RankingAdminTestRepository extends RankingsRepository {
  final events = <CommunityRankingAction>[];
  bool reject = false;
  @override
  Future<List<CommunityRankingAction>> loadRankingActions(
    String communityId,
  ) async => [...events];
  @override
  Future<CommunityRankingAction> manageRankingPlayer(
    String communityId,
    String rankingId,
    String playerKey,
    RankingPlayerAction value,
  ) async {
    if (reject) throw StateError('Permission revoked');
    final event = CommunityRankingAction(
      id: events.length + 1,
      rankingId: rankingId,
      playerKey: playerKey,
      action: value,
      createdAt: DateTime.now(),
    );
    events.add(event);
    return event;
  }
}

class RankingAdminPreview extends StatelessWidget {
  const RankingAdminPreview({
    super.key,
    this.repository,
    this.canManage = true,
  });
  final RankingAdminTestRepository? repository;
  final bool canManage;
  @override
  Widget build(BuildContext context) => CommunityRankingPage(
    communityName: 'Standard-Rangliste',
    communityId: 'community',
    repository: repository ?? RankingAdminTestRepository(),
    canManage: canManage,
    members: eloMembers,
    tournaments: [completedOn(1)],
  );
}

void main() {
  CommunityEloSnapshot calculate(
    List<CreatedTournament> tournaments,
    List<CommunityRankingAction> events, {
    List<CommunityMember>? members,
  }) => const CommunityEloCalculator().calculate(
    members: members ?? eloMembers,
    tournaments: tournaments,
    currentYearOnly: false,
    actions: events,
  );

  test(
    'reset clears only target rating, counters and history; next game starts at 1000',
    () {
      final initial = completedOn(1);
      final reset = action(2, RankingPlayerAction.reset);
      final snapshot = calculate([initial], [reset]);
      expect(snapshot.entries.single.player.playerProfileId, 'b');
      expect(snapshot.entries.single.rating, 984);
      expect(snapshot.history['a'], isNull);
      expect(snapshot.history['b'], hasLength(1));
      final next = calculate([initial, completedOn(3)], [reset]);
      final a = next.entries.firstWhere((e) => e.player.playerProfileId == 'a');
      expect(a.matches, 1);
      expect(a.rating, 1000 + communityEloDelta(1000, 984, 1));
      expect(next.history['a'], hasLength(1));
      expect(
        next.entries.firstWhere((e) => e.player.playerProfileId == 'b').matches,
        2,
      );
    },
  );
  test(
    'remove stops future matches, reset rejoins and repeated resets replay',
    () {
      final events = [
        action(2, RankingPlayerAction.remove),
        action(4, RankingPlayerAction.reset),
      ];
      final beforeRestore = calculate(
        [completedOn(1), completedOn(3)],
        [events.first],
      );
      expect(beforeRestore.excludedPlayerKeys, {'a'});
      expect(beforeRestore.entries.single.rating, 984);
      expect(beforeRestore.entries.single.matches, 1);
      final after = calculate([
        completedOn(1),
        completedOn(3),
        completedOn(5),
      ], events);
      expect(after.excludedPlayerKeys, isEmpty);
      expect(
        after.entries
            .firstWhere((e) => e.player.playerProfileId == 'a')
            .matches,
        1,
      );
      final repeated = calculate(
        [completedOn(1), completedOn(3), completedOn(5)],
        [...events, action(6, RankingPlayerAction.reset)],
      );
      expect(repeated.entries.single.matches, 2);
      expect(repeated.history['a'], isNull);
    },
  );
  test(
    'other rankings unaffected; removed aliases stay removed in yearly and overall',
    () {
      expect(
        calculate(
          [completedOn(1)],
          [action(2, RankingPlayerAction.reset, ranking: 'other')],
        ).entries,
        hasLength(2),
      );
      final alias = CommunityMember(
        userId: 'new',
        playerProfileId: 'new',
        aliasProfileIds: const ['a'],
        displayName: 'Alex',
        role: 'member',
        joinedAt: DateTime(2026),
      );
      final snapshot = calculate(
        [completedOn(1)],
        [action(2, RankingPlayerAction.remove)],
        members: [alias, eloMembers.last],
      );
      expect(snapshot.excludedPlayerKeys, {'new'});
      expect(snapshot.entries, hasLength(1));
      final nextYear = const CommunityEloCalculator().calculate(
        members: eloMembers,
        tournaments: [],
        currentYearOnly: true,
        now: DateTime(2027),
        actions: [action(2, RankingPlayerAction.remove)],
      );
      expect(nextYear.excludedPlayerKeys, {'a'});
    },
  );
  test('tournament forecast respects exclusion and reset', () {
    final t = eloTournament(completed: true);
    (t.runStages.first as GroupTournamentRunStage)
        .groups
        .first
        .matches
        .first
        .finishedAt = DateTime(
      2026,
      1,
      1,
    );
    List<TournamentEloPlayer> preview(RankingPlayerAction value) =>
        const CommunityTournamentElo().calculate(
          tournament: t,
          tournaments: [],
          members: eloMembers,
          rankingId: 'default',
          currentYearOnly: false,
          activeStage: 0,
          actions: [action(2, value)],
        );
    expect(preview(RankingPlayerAction.remove).first.rating, isNull);
    expect(preview(RankingPlayerAction.remove).last.win, isNull);
    expect(preview(RankingPlayerAction.reset).first.rating, 1000);
  });
  testWidgets('readers have no administration actions', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: RankingAdminPreview(canManage: false)),
    );
    await tester.pumpAndSettle();
    expect(find.byTooltip('Spielerwertung verwalten'), findsNothing);
    expect(find.textContaining('1016 Elo'), findsOneWidget);
  });
  testWidgets('remove confirmation, restore and rejected reset', (
    tester,
  ) async {
    final repository = RankingAdminTestRepository();
    await tester.pumpWidget(
      MaterialApp(home: RankingAdminPreview(repository: repository)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Spielerwertung verwalten').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Aus Rangliste entfernen'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Abbrechen'));
    await tester.pumpAndSettle();
    expect(repository.events, isEmpty);
    await tester.tap(find.byTooltip('Spielerwertung verwalten').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Aus Rangliste entfernen'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Entfernen'));
    await tester.pumpAndSettle();
    expect(repository.events.single.action, RankingPlayerAction.remove);
    expect(find.textContaining('1016 Elo'), findsNothing);
    await tester.tap(find.text('Spieler ohne Ranglistenplatz verwalten'));
    await tester.pumpAndSettle();
    expect(find.text('Aus dieser Rangliste entfernt'), findsOneWidget);
    await tester.tap(find.byTooltip('Spielerwertung verwalten').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mit 1000 Elo wieder aufnehmen'));
    await tester.pumpAndSettle();
    repository.reject = true;
    await tester.tap(find.text('Zurücksetzen'));
    await tester.pumpAndSettle();
    expect(repository.events, hasLength(1));
    expect(find.textContaining('Änderung nicht bestätigt'), findsOneWidget);
    expect(find.text('Aus dieser Rangliste entfernt'), findsOneWidget);
  });
  for (final size in [
    const Size(360, 800),
    const Size(800, 600),
    const Size(1440, 900),
  ]) {
    testWidgets('ranking management and dialog at $size with large text', (
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
          home: const RankingAdminPreview(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byTooltip('Spielerwertung verwalten').first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Spielerwertung verwalten').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Spielerwertung zurücksetzen'));
      await tester.pumpAndSettle();
      expect(find.text('Spielerwertung zurücksetzen?'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
