import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_tournament_manager/features/communities/domain/community_permissions.dart';
import 'package:dart_tournament_manager/features/communities/presentation/widgets/community_tournament_actions.dart';
import 'package:dart_tournament_manager/features/tournaments/application/tournament_creation_controller.dart';
import 'package:dart_tournament_manager/features/tournaments/data/tournament_storage.dart';
import 'package:dart_tournament_manager/features/tournaments/domain/tournament_models.dart';

void main() {
  test('unranked choice persists, syncs and requires edit permission to change', () async {
    final directory = await Directory.systemTemp.createTemp('ranking-setting');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/tournaments.json');
    await file.writeAsString(jsonEncode({'schemaVersion': 13, 'tournaments': []}));
    final grants = {CommunityPermission.createTournaments};
    final uploaded = <Map<String, dynamic>>[];
    var userId = 'user';
    final storage = TournamentStorage(
      file: file,
      currentUserId: () => userId,
      authorize: (_, permission) async {
        if (!grants.contains(permission)) throw StateError('denied');
      },
      upload: (payload) async => uploaded.add(payload),
    );
    final tournament = await TournamentCreationController(storage: storage).createCommunityTournament(
      name: 'Freundschaftsturnier', players: [], stages: [], runStages: [],
      communityId: 'community', countsForRanking: false,
      communityRankingIds: ['training', 'default'],
    );
    expect((await storage.loadTournaments()).single.countsForRanking, isFalse);
    expect(jsonDecode(await file.readAsString())['schemaVersion'], 20);
    expect(await File('${file.path}.v13.bak').exists(), isTrue);
    await storage.synchronize();
    expect((uploaded.single['payload'] as Map)['countsForRanking'], isFalse);
    expect((uploaded.single['payload'] as Map)['communityRankingIds'], ['training', 'default']);
    final edited = CreatedTournament.fromJson(tournament.toJson()..['countsForRanking'] = true);
    userId = 'other-member';
    await expectLater(storage.saveTournament(edited), throwsStateError);
    grants.add(CommunityPermission.editTournaments);
    await storage.saveTournament(edited);
    expect((await storage.loadTournaments()).single.countsForRanking, isTrue);
  });

  for (final size in [const Size(360, 800), const Size(800, 600), const Size(1440, 900)]) {
    testWidgets('ranking setting can be toggled at $size with large text', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(2)), child: child!),
        home: Scaffold(body: CommunityTournamentActions(
          tournament: CreatedTournament(name: 'Test', communityId: 'g', players: [], stages: [], runStages: []),
          permissions: CommunityPermissions(['edit_tournaments']), onChanged: () {},
        )),
      ));
      await tester.tap(find.byTooltip('Turnieraktionen'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Turnier bearbeiten'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.byType(SwitchListTile), 150, scrollable: find.byType(Scrollable).first);
      expect(tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value, isTrue);
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value, isFalse);
      expect(tester.takeException(), isNull);
    });
  }
}
