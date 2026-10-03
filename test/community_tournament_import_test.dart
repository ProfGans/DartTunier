import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_tournament_manager/features/communities/application/community_tournament_import.dart';
import 'package:dart_tournament_manager/features/communities/presentation/community_tournament_import_page.dart';
import 'package:dart_tournament_manager/features/communities/domain/community.dart';
import 'package:dart_tournament_manager/features/communities/domain/community_permissions.dart';
import 'package:dart_tournament_manager/features/tournaments/data/tournament_storage.dart';
import 'package:dart_tournament_manager/features/tournaments/domain/tournament_models.dart';
import 'community_rankings_test.dart' show RankingsRepository;
import 'community_tournament_elo_test.dart' show eloTournament, eloMembers;

CreatedTournament localImportFixture() => CreatedTournament.fromJson({
  ...eloTournament(completed: true).toJson(),
  'communityId': null,
});

class ImportRepository extends RankingsRepository {
  @override
  Future<List<CreatedTournament>> loadTournaments(String communityId) async =>
      [];
  @override
  Future<List<CommunityMember>> loadMembers(String communityId) async =>
      eloMembers;
}

class ImportPreviewStorage extends TournamentStorage {
  @override
  Future<List<CreatedTournament>> loadTournaments() async => [
    localImportFixture(),
  ];
}

class TournamentImportPreview extends StatelessWidget {
  const TournamentImportPreview({super.key});
  @override
  Widget build(BuildContext context) => CommunityTournamentImportPage(
    community: Community(
      id: 'community',
      name: 'Dartclub',
      description: '',
      inviteCode: '',
      ownerUserId: 'owner',
      createdAt: DateTime(2026),
    ),
    repository: ImportRepository(),
    storage: ImportPreviewStorage(),
  );
}

void main() {
  test(
    'copy preserves original and results, maps identities throughout bracket',
    () {
      final local = localImportFixture();
      final original = local.toJson();
      final copy = CommunityTournamentImport.copy(
        local,
        'community',
        assignments: {
          'a': CommunityMember(
            userId: 'new',
            playerProfileId: 'new',
            displayName: 'Neues Profil',
            role: 'member',
            joinedAt: DateTime(2026),
          ),
        },
      );
      expect(local.toJson(), original);
      expect(copy.id, CommunityTournamentImport.id('community', local.id));
      expect(copy.communityId, 'community');
      expect(copy.countsForRanking, isFalse);
      final match = (copy.runStages.first as GroupTournamentRunStage)
          .groups
          .first
          .matches
          .first;
      expect(match.homePlayer!.profileId, 'new');
      expect(match.homePlayer!.name, local.players.first.name);
      expect(match.homeLegs, 3);
      expect(
        () => CommunityTournamentImport.copy(copy, 'other'),
        throwsArgumentError,
      );
      expect(
        () => CommunityTournamentImport.copy(
          local,
          'community',
          assignments: {'a': eloMembers.first, 'b': eloMembers.first},
        ),
        throwsArgumentError,
      );
    },
  );
  test(
    'import persists beside local original and survives offline upload',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'community_import',
      );
      addTearDown(() => directory.delete(recursive: true));
      final required = <CommunityPermission>[];
      final file = File('${directory.path}/data.json');
      final storage = TournamentStorage(
        file: file,
        currentUserId: () => 'owner',
        authorize: (_, permission) async => required.add(permission),
        upload: (_) async => throw StateError('offline'),
      );
      final local = localImportFixture();
      await storage.saveTournament(local);
      final copy = CommunityTournamentImport.copy(local, 'community');
      await storage.saveTournament(copy);
      await storage.synchronize(tournamentId: copy.id);
      final restored = await storage.loadTournaments();
      expect(restored, hasLength(2));
      expect(restored.singleWhere((t) => t.id == local.id).communityId, isNull);
      expect(required, contains(CommunityPermission.createTournaments));
      expect(await file.readAsString(), contains('pending'));
    },
  );
  for (final size in [
    const Size(360, 800),
    const Size(800, 600),
    const Size(1440, 900),
  ]) {
    testWidgets('import setup at $size with large text', (tester) async {
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
          home: const TournamentImportPreview(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byType(DropdownButtonFormField<CreatedTournament>).hitTestable(),
        150,
      );
      await tester.tap(find.byType(DropdownButtonFormField<CreatedTournament>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Elo-Test · 2 Spieler').last);
      await tester.pumpAndSettle();
      for (var i = 0; i < 6; i++) {
        expect(tester.takeException(), isNull);
        await tester.drag(find.byType(Scrollable).first, const Offset(0, -300));
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull);
    });
  }
}
