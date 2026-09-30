import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dart_tournament_manager/features/communities/presentation/community_page.dart';
import 'package:dart_tournament_manager/features/communities/data/supabase_community_repository.dart';
import 'package:dart_tournament_manager/features/communities/domain/community.dart';
import 'package:dart_tournament_manager/features/tournaments/domain/tournament_models.dart';

class MenuRepository extends SupabaseCommunityRepository {
  MenuRepository()
    : super(client: SupabaseClient('https://example.test', 'test'));
  int memberLoads = 0;
  int tournamentLoads = 0;
  @override
  String get currentUserId => 'owner';
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
    await tester.scrollUntilVisible(find.text('Einladen'), 150);
      await tester.pumpAndSettle();
    await tester.tap(find.text('Einladen'));
    await tester.pumpAndSettle();
    expect(find.text('Einladen · Dartclub'), findsOneWidget);
    expect(repository.memberLoads, 1);
    expect(repository.tournamentLoads, 1);
    expect(tester.takeException(), isNull);
  });
}
