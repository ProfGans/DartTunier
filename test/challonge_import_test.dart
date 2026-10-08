import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_tournament_manager/features/communities/application/challonge_import_service.dart';
import 'package:dart_tournament_manager/features/communities/data/challonge_client.dart';
import 'package:dart_tournament_manager/features/communities/domain/challonge_tournament.dart';
import 'package:dart_tournament_manager/features/communities/domain/community.dart';
import 'package:dart_tournament_manager/features/communities/presentation/challonge_import_page.dart';
import 'package:dart_tournament_manager/features/communities/presentation/challonge_archive_page.dart';
import 'package:dart_tournament_manager/features/tournaments/domain/tournament_models.dart';
import 'package:dart_tournament_manager/features/tournaments/data/tournament_storage.dart';
import 'community_tournament_import_test.dart'
    show ImportRepository, ImportPreviewStorage;

Map<String, dynamic> challongeFixture({int id = 7}) => {
  'id': id,
  'name': 'Historisches Vereinsturnier mit langer deutscher Bezeichnung',
  'state': 'complete',
  'tournament_type': 'double elimination',
  'teams': false,
  'participants_count': 3,
  'created_at': '2020-01-01T12:00:00Z',
  'completed_at': '2020-01-01T18:00:00Z',
  'participants': [
    for (var i = 1; i <= 3; i++)
      {
        'participant': {
          'id': i,
          'name': ['Anna', 'Ben', 'Clara'][i - 1],
          'final_rank': i == 1 ? 1 : 2,
        },
      },
  ],
  'matches': [
    {
      'match': {
        'id': 1,
        'round': 1,
        'state': 'complete',
        'player1_id': 1,
        'player2_id': 2,
        'winner_id': 1,
        'scores_csv': '3-1',
      },
    },
    {
      'match': {
        'id': 2,
        'round': -1,
        'state': 'complete',
        'player1_id': 2,
        'player2_id': 3,
        'winner_id': 2,
        'scores_csv': '2-1,1-2,2-0',
      },
    },
    {
      'match': {
        'id': 3,
        'round': 2,
        'state': 'complete',
        'player1_id': 1,
        'player2_id': 3,
        'winner_id': 1,
        'scores_csv': '',
      },
    },
  ],
};
CommunityMember member(String name, String id) => CommunityMember(
  userId: null,
  playerProfileId: id,
  displayName: name,
  role: 'member',
  joinedAt: DateTime(2020),
);

class PreviewChallongeClient extends ChallongeClient {
  @override
  Future<ChallongeTournament> tournament(
    String apiKey,
    String identifier,
  ) async => ChallongeTournament(challongeFixture());
}

class ChallongeImportPreview extends StatelessWidget {
  const ChallongeImportPreview({super.key});
  @override
  Widget build(BuildContext context) => ChallongeImportPage(
    community: Community(
      id: 'community',
      name: 'Dartclub',
      description: '',
      inviteCode: '',
      ownerUserId: 'owner',
      createdAt: DateTime(2020),
    ),
    repository: ImportRepository(),
    storage: ImportPreviewStorage(),
    client: PreviewChallongeClient(),
  );
}

class ChallongeArchivePreview extends StatelessWidget {
  const ChallongeArchivePreview({super.key});
  @override
  Widget build(BuildContext context) => ChallongeArchivePage(
    tournament: ChallongeTournament(
      challongeFixture(),
    ).convert('community', {'1': 'a', '2': 'b', '3': 'c'}),
  );
}

void main() {
  test(
    'historical archive persists through versioned storage migration',
    () async {
      final temp = await Directory.systemTemp.createTemp(
        'challonge-import-test-',
      );
      addTearDown(() => temp.delete(recursive: true));
      final file = File('${temp.path}/tournaments.json');
      await file.writeAsString(
        jsonEncode({'schemaVersion': 16, 'tournaments': []}),
      );
      final storage = TournamentStorage(
        file: file,
        currentUserId: () => null,
        authorize: (id, p) async {},
      );
      final imported = ChallongeTournament(
        challongeFixture(),
      ).convert('c', {'1': 'a', '2': 'b', '3': 'c'});
      await storage.saveTournament(imported);
      final restored = (await storage.loadTournaments()).single;
      expect(
        restored.importedArchive!.toJson(),
        imported.importedArchive!.toJson(),
      );
      expect(await File('${file.path}.v16.bak').exists(), isTrue);
      expect(
        jsonDecode(await file.readAsString())['schemaVersion'],
        greaterThanOrEqualTo(17),
      );
    },
  );
  test('group-stage participant aliases map to the same community player', () {
    final data = challongeFixture();
    final participants = data['participants'] as List;
    (participants.first['participant'] as Map)['group_player_ids'] = [101];
    ((data['matches'] as List).first['match'] as Map)
      ..['player1_id'] = 101
      ..['winner_id'] = 101;
    final imported = ChallongeTournament(
      data,
    ).convert('c', {'1': 'a', '2': 'b', '3': 'c'});
    final match = (imported.runStages.single as GroupTournamentRunStage)
        .groups
        .single
        .matches
        .single;
    expect(match.homePlayer!.profileId, 'a');
    expect(imported.importedArchive!.matches.first['winner_id'], 101);
  });
  test('member creation permission fails before any import writes', () async {
    var writes = 0;
    final service = ChallongeImportService(
      loadMembers: () async => [],
      loadTournaments: () async => [],
      authorizeMemberCreation: () async {
        throw StateError('not owner');
      },
      createMember: (name) async {
        writes++;
        return member(name, 'new');
      },
      saveTournament: (t) async {
        writes++;
      },
    );
    await expectLater(
      service.import('c', [ChallongeTournament(challongeFixture())]),
      throwsStateError,
    );
    expect(writes, 0);
  });
  test(
    'archive retains exact scores, tied ranks, dates and survives storage roundtrip',
    () {
      final source = ChallongeClient.decodeExport(
        jsonEncode({'tournament': challongeFixture()}),
      ).single;
      final imported = source.convert('community', {
        '1': 'a',
        '2': 'b',
        '3': 'c',
      });
      final restored = CreatedTournament.fromJson(imported.toJson());
      expect(
        restored.importedArchive!.toJson(),
        imported.importedArchive!.toJson(),
      );
      expect(
        restored.importedArchive!.participants.map((p) => p['finalRank']),
        [1, 2, 2],
      );
      expect(restored.importedArchive!.matches[1]['scores_csv'], '2-1,1-2,2-0');
      expect(
        (restored.runStages.single as GroupTournamentRunStage)
            .groups
            .single
            .matches
            .length,
        1,
      );
      expect(restored.finishedAt, DateTime.utc(2020, 1, 1, 18));
      expect(restored.countsForRanking, isFalse);
      expect(
        CreatedTournament.fromJson(
          {...imported.toJson()}..remove('importedArchive'),
        ).importedArchive,
        isNull,
      );
    },
  );
  test(
    'reject incomplete, ongoing, unknown players, teams and ambiguous names before writes',
    () {
      for (final change in [
        {'state': 'underway'},
        {'participants_count': 4},
        {'teams': true},
        {'matches': null},
        {
          'participants': [
            {'id': 1, 'name': 'Anna'},
            {'id': 2, 'name': ' anna '},
            {'id': 3, 'name': 'Clara'},
          ],
        },
        {
          'matches': [
            {'id': 5, 'player1_id': 99},
          ],
        },
      ]) {
        expect(
          () => ChallongeTournament({...challongeFixture(), ...change}),
          throwsFormatException,
        );
      }
    },
  );
  test(
    'batch reuses normalized names across tournaments and repeated import skips all writes',
    () async {
      final members = [member(' ANNA ', 'a')];
      final saved = <CreatedTournament>[];
      var created = 0;
      final service = ChallongeImportService(
        loadMembers: () async => members,
        createMember: (name) async {
          created++;
          final m = member(name, 'new$created');
          members.add(m);
          return m;
        },
        loadTournaments: () async => saved,
        saveTournament: (t) async {
          saved.add(t);
        },
      );
      final sources = [
        ChallongeTournament(challongeFixture()),
        ChallongeTournament(challongeFixture(id: 8)),
      ];
      expect(await service.import('c', sources), 2);
      expect(created, 2);
      expect(saved.first.players.first.profileId, 'a');
      expect(await service.import('c', sources), 0);
      expect(created, 2);
    },
  );
  test(
    'ambiguous assignments and merged identities cause no member creation',
    () async {
      var writes = 0;
      final service = ChallongeImportService(
        loadMembers: () async => [member('Anna', 'a'), member('Anna', 'b')],
        createMember: (name) async {
          writes++;
          return member(name, 'new');
        },
        loadTournaments: () async => [],
        saveTournament: (t) async {
          writes++;
        },
      );
      final sources = [ChallongeTournament(challongeFixture())];
      await expectLater(service.import('c', sources), throwsStateError);
      await expectLater(
        service.import('c', sources, assignments: {'anna': 'a', 'ben': 'a'}),
        throwsStateError,
      );
      expect(writes, 0);
    },
  );
  test('retry after failed save reuses already created members', () async {
    final members = <CommunityMember>[];
    final saved = <CreatedTournament>[];
    var created = 0, fail = true;
    final service = ChallongeImportService(
      loadMembers: () async => members,
      createMember: (name) async {
        final m = member(name, 'p${++created}');
        members.add(m);
        return m;
      },
      loadTournaments: () async => saved,
      saveTournament: (t) async {
        if (fail) throw StateError('offline');
        saved.add(t);
      },
    );
    final sources = [ChallongeTournament(challongeFixture())];
    await expectLater(service.import('c', sources), throwsStateError);
    fail = false;
    expect(await service.import('c', sources), 1);
    expect(created, 3);
  });
  for (final size in [
    const Size(360, 800),
    const Size(800, 600),
    const Size(1440, 900),
  ]) {
    testWidgets('preview, mapping and resize at $size with large text', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: const ChallongeImportPreview(),
        ),
      );
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('challonge-links')),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.enterText(
        find.byKey(const ValueKey('challonge-links')),
        'https://challonge.com/archiv_7',
      );
      await tester.scrollUntilVisible(
        find.text('Importvorschau laden'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Importvorschau laden'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Anna'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(tester.takeException(), isNull);
      tester.view.physicalSize = const Size(360, 800);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('challonge-links')),
        -200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('https://challonge.com/archiv_7'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(
        const MaterialApp(home: ChallongeArchivePreview()),
      );
      await tester.pumpAndSettle();
      expect(find.text('2. Ben'), findsOneWidget);
      expect(find.text('2. Clara'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
