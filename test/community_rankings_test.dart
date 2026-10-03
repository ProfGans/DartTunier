import 'package:flutter/material.dart';
import 'package:dart_tournament_manager/features/communities/domain/community_ranking_action.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dart_tournament_manager/features/communities/data/supabase_community_repository.dart';
import 'package:dart_tournament_manager/features/communities/domain/community.dart';
import 'package:dart_tournament_manager/features/communities/domain/community_permissions.dart';
import 'package:dart_tournament_manager/features/communities/domain/community_ranking.dart';
import 'package:dart_tournament_manager/features/communities/presentation/community_rankings_page.dart';
import 'package:dart_tournament_manager/features/communities/presentation/widgets/community_ranking_picker.dart';

class RankingsRepository extends SupabaseCommunityRepository {
  RankingsRepository({this.multiple = false})
    : super(
        client: SupabaseClient(
          'https://example.test',
          'test',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
      );
  final bool multiple;
  @override
  Future<List<CommunityRankingAction>> loadRankingActions(String communityId) async => [];
  @override
  Future<List<CommunityRanking>> loadRankings(String communityId) async => [
    CommunityRanking.standard,
    if (multiple)
      const CommunityRanking(
        id: 'training',
        name: 'Vereinsmeisterschaft am Wochenende',
      ),
  ];
  @override
  Future<CommunityRanking> createRanking(
    String communityId,
    String name,
  ) async => CommunityRanking(id: 'new', name: name);
}

Widget rankingFixture({bool multiple = true, bool canEdit = true}) => RankingsPreview(multiple: multiple, canEdit: canEdit);

class RankingsPreview extends StatelessWidget {
  const RankingsPreview({super.key, required this.multiple, required this.canEdit});
  final bool multiple;
  final bool canEdit;
  @override
  Widget build(BuildContext context) => Scaffold(
  appBar: AppBar(title: const Text('Rangliste · Dartverein')),
  body: CommunityRankingsPage(
    community: Community(
      id: 'club',
      name: 'Dartverein',
      description: '',
      inviteCode: '',
      ownerUserId: 'owner',
      createdAt: DateTime(2026),
    ),
    repository: RankingsRepository(multiple: multiple),
    permissions: CommunityPermissions(canEdit ? ['edit_community'] : []),
    members: const [],
    tournaments: const [],
  ),
);
}

void main() {
  testWidgets('one ranking opens directly and creation switches to selection', (
    tester,
  ) async {
    await tester.pumpWidget(MaterialApp(home: rankingFixture(multiple: false)));
    await tester.pumpAndSettle();
    expect(find.text('Dieses Jahr'), findsOneWidget);
    await tester.tap(find.text('Rangliste erstellen'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'Training');
    await tester.tap(find.text('Erstellen'));
    await tester.pumpAndSettle();
    expect(find.text('Standard-Rangliste'), findsOneWidget);
    expect(find.text('Training'), findsOneWidget);
    expect(find.text('Dieses Jahr'), findsNothing);
    await tester.tap(find.text('Training'));
    await tester.pumpAndSettle();
    expect(find.text('Dieses Jahr'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Training'), findsOneWidget);
  });

  testWidgets('readers can select rankings but cannot create them', (
    tester,
  ) async {
    await tester.pumpWidget(MaterialApp(home: rankingFixture(canEdit: false)));
    await tester.pumpAndSettle();
    expect(find.text('Rangliste erstellen'), findsNothing);
    expect(find.text('Standard-Rangliste'), findsOneWidget);
  });

  for (final size in [
    const Size(360, 800),
    const Size(800, 600),
    const Size(1440, 900),
  ]) {
    testWidgets('ranking selection at $size and 200 percent text', (
      tester,
    ) async {
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
          home: rankingFixture(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Dieses Jahr'), findsNothing);
      await tester.tap(find.text('Vereinsmeisterschaft am Wochenende'));
      await tester.pumpAndSettle();
      expect(find.text('Dieses Jahr'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'picker assigns multiple rankings and preserves unknown IDs on load failure',
    (tester) async {
      var ids = ['default'];
      var fail = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => CommunityRankingPicker(
                communityId: 'club',
                selectedIds: ids,
                onChanged: (value) => setState(() => ids = value),
                loadRankings: () async {
                  if (fail) throw StateError('offline');
                  return [
                    CommunityRanking.standard,
                    const CommunityRanking(id: 'training', name: 'Training'),
                  ];
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Training'));
      await tester.pumpAndSettle();
      expect(ids, ['default', 'training']);
      await tester.tap(find.text('Standard-Rangliste'));
      await tester.pumpAndSettle();
      expect(ids, ['training']);
      fail = true;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CommunityRankingPicker(
              key: const ValueKey('offline'),
              communityId: 'club',
              selectedIds: ids,
              onChanged: (value) => ids = value,
              loadRankings: () async => throw StateError('offline'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Weitere Ranglisten erneut laden'), findsOneWidget);
      expect(ids, ['training']);
    },
  );
}
