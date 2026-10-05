import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dart_tournament_manager/features/communities/presentation/community_page.dart';
import 'package:dart_tournament_manager/features/communities/data/supabase_community_repository.dart';
import 'package:dart_tournament_manager/features/communities/domain/community.dart';
import 'package:dart_tournament_manager/features/tournaments/domain/tournament_models.dart';
import 'package:dart_tournament_manager/features/communities/data/community_access_repository.dart';
import 'package:dart_tournament_manager/features/communities/domain/community_permissions.dart';

class MenuAccess extends CommunityAccessRepository {
  MenuAccess({this.canEdit = true});
  final bool canEdit;
  @override
  Future<CommunityPermissions> permissions(String id) async =>
      CommunityPermissions(
        CommunityPermission.values
            .where((p) => canEdit || p != CommunityPermission.editCommunity)
            .map((p) => p.key),
      );
  @override
  Future<String> invitation(String id) async => 'ABCD1234';
}

class MenuRepository extends SupabaseCommunityRepository {
  MenuRepository({this.canEdit = true})
    : super(
        client: SupabaseClient(
          'https://example.test',
          'test',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
      );
  int memberLoads = 0;
  final bool canEdit;
  @override
  CommunityAccessRepository get access => MenuAccess(canEdit: canEdit);
  int tournamentLoads = 0;
  @override
  String get currentUserId => 'member';
  @override
  Future<List<CommunityMember>> loadMembers(String id) async {
    memberLoads++;
    return [];
  }

  @override
  Future<List<CreatedTournament>> loadTournaments(String id) async {
    tournamentLoads++;
    return [];
  }
}

void main() {
  testWidgets('member without edit right receives a permission explanation', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CommunityDetailPage(
          community: Community(
            id: 'club',
            name: 'Dartclub',
            description: '',
            inviteCode: '',
            ownerUserId: 'owner',
            createdAt: DateTime(2026),
          ),
          repository: MenuRepository(canEdit: false),
        ),
      ),
    );
    await tester.pumpAndSettle();
    if (find.text('Community bearbeiten').hitTestable().evaluate().isEmpty) {
      await tester.ensureVisible(find.text('Community verwalten'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Community verwalten'));
      await tester.pumpAndSettle();
    }
    await tester.scrollUntilVisible(find.text('Community bearbeiten'), 150);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Community bearbeiten'));
    await tester.pumpAndSettle();
    expect(
      find.text('Deiner Rolle fehlt das Recht „Community bearbeiten“.'),
      findsOneWidget,
    );
    expect(find.byType(TextFormField), findsNothing);
  });
  testWidgets('community menu separates areas and loads only opened content', (
    tester,
  ) async {
    final repository = MenuRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: CommunityDetailPage(
          community: Community(
            id: 'club',
            name: 'Dartclub',
            description: '',
            inviteCode: 'ABCD1234',
            ownerUserId: 'owner',
            createdAt: DateTime(2026),
          ),
          repository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(repository.memberLoads, 0);
    expect(repository.tournamentLoads, 0);
    expect(find.text('Community-Menü'), findsOneWidget);
    await tester.tap(find.text('Turniere'));
    await tester.pumpAndSettle();
    expect(find.text('Turniere · Dartclub'), findsOneWidget);
    expect(find.text('Community-Turnier erstellen'), findsOneWidget);
    expect(repository.tournamentLoads, 1);
    expect(repository.memberLoads, 0);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mitglieder'));
    await tester.pumpAndSettle();
    expect(find.text('Mitglieder · Dartclub'), findsOneWidget);
    expect(repository.memberLoads, 1);
    expect(repository.tournamentLoads, 1);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Community verwalten'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Community verwalten'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Einladen'), 150);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Einladen'));
    await tester.pumpAndSettle();
    expect(find.text('Einladen · Dartclub'), findsOneWidget);
    expect(repository.memberLoads, 1);
    expect(repository.tournamentLoads, 1);
    expect(tester.takeException(), isNull);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Statistik'));
    await tester.tap(find.text('Statistik'));
    await tester.pumpAndSettle();
    expect(find.text('Statistik · Dartclub'), findsOneWidget);
    expect(find.text('Spielerstatistiken'), findsOneWidget);
    expect(repository.memberLoads, 2);
    expect(repository.tournamentLoads, 2);
    await tester.pageBack();
    await tester.pumpAndSettle();
    if (find.text('Community bearbeiten').hitTestable().evaluate().isEmpty) {
      await tester.ensureVisible(find.text('Community verwalten'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Community verwalten'));
      await tester.pumpAndSettle();
    }
    await tester.scrollUntilVisible(find.text('Community bearbeiten'), 150);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Community bearbeiten'));
    await tester.pumpAndSettle();
    expect(find.text('Community bearbeiten'), findsOneWidget);
    expect(find.byType(TextFormField), findsWidgets);
  });
}
