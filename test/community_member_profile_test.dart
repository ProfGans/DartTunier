import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_tournament_manager/features/communities/domain/community.dart';
import 'package:dart_tournament_manager/features/communities/presentation/community_member_profile_page.dart';
import 'package:dart_tournament_manager/features/communities/presentation/widgets/community_members_section.dart';
import 'package:dart_tournament_manager/features/tournaments/domain/tournament_models.dart';
import 'community_rankings_test.dart' show RankingsRepository;
import 'community_tournament_elo_test.dart' show eloMembers, eloTournament;

class MemberProfileRepository extends RankingsRepository {
  @override
  String get currentUserId => 'reader';
  @override
  Future<List<CreatedTournament>> loadTournaments(String communityId) async => [
    eloTournament(completed: true),
  ];
}

Community get profileCommunity => Community(
  id: 'community',
  name: 'Dartclub',
  description: '',
  inviteCode: '',
  ownerUserId: 'owner',
  createdAt: DateTime(2026),
);

class MemberProfilePreview extends StatelessWidget {
  const MemberProfilePreview({super.key});
  @override
  Widget build(BuildContext context) => CommunityMemberProfilePage(
    community: profileCommunity,
    member: eloMembers.first,
    members: eloMembers,
    repository: MemberProfileRepository(),
  );
}

void main() {
  testWidgets('member list opens profile and personal statistics', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CommunityMembersSection(
            community: profileCommunity,
            members: eloMembers,
            repository: MemberProfileRepository(),
            onChanged: () {},
          ),
        ),
      ),
    );
    await tester.tap(find.text(eloMembers.first.displayName));
    await tester.pumpAndSettle();
    expect(find.text('Mitgliederprofil'), findsOneWidget);
    expect(find.text('Mitglied seit 1.1.2026'), findsOneWidget);
    expect(
      find.text('1 Siege · 0 Unentschieden · 0 Niederlagen'),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(
      find.text('Persönliche Statistik öffnen').hitTestable(),
      150,
    );
    await tester.tap(find.text('Persönliche Statistik öffnen'));
    await tester.pumpAndSettle();
    expect(find.text('Spielerstatistik'), findsOneWidget);
  });
  testWidgets('linked manual member resolves to account statistics', (
    tester,
  ) async {
    final manual = CommunityMember(
      userId: null,
      playerProfileId: 'guest',
      displayName: 'Gastname',
      role: 'member',
      linkedUserId: eloMembers.first.userId,
      joinedAt: DateTime(2026),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: CommunityMemberProfilePage(
          community: profileCommunity,
          member: manual,
          members: [...eloMembers, manual],
          repository: MemberProfileRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Gastname'), findsOneWidget);
    expect(find.textContaining('Zugeordneter Account:'), findsOneWidget);
    expect(
      find.text('1 Siege · 0 Unentschieden · 0 Niederlagen'),
      findsOneWidget,
    );
  });
  testWidgets('manual member without games still has a profile', (
    tester,
  ) async {
    final manual = CommunityMember(
      userId: null,
      playerProfileId: 'guest',
      displayName: 'Neu',
      role: 'member',
      joinedAt: DateTime(2026),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: CommunityMemberProfilePage(
          community: profileCommunity,
          member: manual,
          members: [...eloMembers, manual],
          repository: MemberProfileRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Noch keine abgeschlossenen Spiele in dieser Community.'),
      findsOneWidget,
    );
  });
  for (final size in [
    const Size(360, 800),
    const Size(800, 600),
    const Size(1440, 900),
  ]) {
    testWidgets('member profile at $size with large text', (tester) async {
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
          home: const MemberProfilePreview(),
        ),
      );
      await tester.pumpAndSettle();
      for (var i = 0; i < 5; i++) {
        expect(tester.takeException(), isNull);
        await tester.drag(find.byType(Scrollable).first, const Offset(0, -250));
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull);
    });
  }
}
