import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_tournament_manager/features/communities/domain/community.dart';
import 'package:dart_tournament_manager/features/communities/presentation/widgets/community_menu.dart';
import 'package:dart_tournament_manager/features/communities/presentation/community_profile_page.dart';
import 'community_profile_test.dart' show ProfileRepository;

void main() {
  final json = {'id': 'c', 'owner_user_id': 'owner', 'name': 'Club'};
  test('older cached communities retain rankings', () {
    expect(Community.fromJson(json).rankingEnabled, isTrue);
    expect(
      Community.fromJson({...json, 'ranking_enabled': false}).rankingEnabled,
      isFalse,
    );
  });
  testWidgets('ranking is optional but statistics remain available', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CommunityMenu(
            description: '',
            rankingEnabled: false,
            onSelected: (_) {},
          ),
        ),
      ),
    );
    expect(find.text('Rangliste'), findsNothing);
    await tester.scrollUntilVisible(find.text('Statistik'), 100);
    expect(find.text('Statistik'), findsOneWidget);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CommunityMenu(description: '', onSelected: (_) {}),
        ),
      ),
    );
    await tester.scrollUntilVisible(find.text('Rangliste'), 100);
    expect(find.text('Rangliste'), findsOneWidget);
  });
  testWidgets('settings can enable a previously disabled ranking', (
    tester,
  ) async {
    final repository = ProfileRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: CommunityProfilePage(
          community: Community.fromJson({...json, 'ranking_enabled': false}),
          repository: repository,
        ),
      ),
    );
    await tester.scrollUntilVisible(
      find.text('Rangliste aktivieren'),
      100,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Änderungen speichern'),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Änderungen speichern'));
    await tester.pumpAndSettle();
    expect(repository.saved!.rankingEnabled, isTrue);
  });
}
