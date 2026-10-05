import 'package:dart_tournament_manager/features/statistics/presentation/analytics/player_analytics_page.dart';
import 'statistics_analytics_widget_test.dart'
    show
        PlayerAnalyticsPreview,
        CommunityAnalyticsPreview,
        MetricAnalyticsPreview;
import 'package:shared_preferences/shared_preferences.dart';
import 'community_rankings_test.dart' show rankingFixture;
import 'community_calendar_test.dart'
    show CalendarPreview, AppointmentEditorPreview;
import 'community_tournament_elo_test.dart' show TournamentEloPreview;
import 'community_ranking_admin_test.dart' show RankingAdminPreview;
import 'community_live_ranking_test.dart' show LiveRankingPreview;
import 'community_member_profile_test.dart' show MemberProfilePreview;
import 'community_tournament_import_test.dart' show TournamentImportPreview;
import 'player_profile_picker_creation_test.dart'
    show PlayerPickerCreationPreview;
import 'community_trends_test.dart' show CommunityTrendsPreview;
import 'tournament_results_statistics_test.dart' show ResultsStatisticsPreview;
import 'community_highlights_test.dart'
    show CommunityHighlightsPreview, HighlightEditorPreview;
import 'community_statistics_navigation_test.dart'
    show CommunityStatisticsPreview, CommunityPlayerStatisticsPreview;
import 'package:dart_tournament_manager/features/statistics/presentation/statistics_date_dialog.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_tournament_manager/features/league/domain/league_match.dart';
import 'package:dart_tournament_manager/features/tournaments/presentation/widgets/creation/team_participant_list.dart';
import 'package:dart_tournament_manager/features/league/presentation/league_match_page.dart';
import 'package:dart_tournament_manager/tournament_workspace.dart';
import 'package:dart_tournament_manager/features/settings/presentation/settings_page.dart';
import 'package:dart_tournament_manager/features/scorer/presentation/scorer_match_page.dart';
import 'package:dart_tournament_manager/features/scorer/domain/scorer_settings.dart';
import 'package:dart_tournament_manager/shared/persistence/storage_access.dart';
import 'package:dart_tournament_manager/app/app_theme.dart';
import 'package:dart_tournament_manager/features/communities/presentation/community_page.dart';
import 'package:dart_tournament_manager/features/communities/presentation/community_roles_page.dart';
import 'package:dart_tournament_manager/features/communities/presentation/community_profile_page.dart';
import 'package:dart_tournament_manager/features/communities/domain/community_permissions.dart';
import 'package:dart_tournament_manager/features/communities/domain/community.dart';
import 'package:dart_tournament_manager/features/communities/domain/community_elo.dart';
import 'support/community_role_fakes.dart';
import 'package:dart_tournament_manager/features/players/presentation/players_page.dart';
import 'package:dart_tournament_manager/features/dev_tools/presentation/dev_tools_page.dart';
import 'package:dart_tournament_manager/features/scorer/presentation/scorer_page.dart';
import 'package:dart_tournament_manager/features/autoscoring/presentation/autoscoring_page.dart';
import 'package:dart_tournament_manager/features/autoscoring/presentation/autoscore_demo_page.dart';
import 'package:dart_tournament_manager/features/scorer/presentation/scorer_setup_page.dart';
import 'package:dart_tournament_manager/features/scorer/domain/scorer_opponents.dart';
import 'package:dart_tournament_manager/features/scorer/presentation/lobby/scorer_join_page.dart';
import 'package:dart_tournament_manager/features/scorer/presentation/checkout_page.dart';
import 'package:dart_tournament_manager/features/scorer/presentation/bot_settings_page.dart';
import 'package:dart_tournament_manager/features/tournaments/presentation/pages/tournament_results_page.dart';
import 'package:dart_tournament_manager/features/tournaments/domain/tournament_models.dart';
import 'package:dart_tournament_manager/features/tournaments/data/app_database.dart';
import 'package:dart_tournament_manager/features/accounts/application/account_session_store.dart';
import 'package:dart_tournament_manager/features/accounts/domain/account_user.dart';
import 'package:dart_tournament_manager/features/statistics/data/player_statistics_repository.dart';
import 'package:dart_tournament_manager/features/statistics/domain/saved_scorer_match.dart';
import 'package:dart_tournament_manager/features/scorer/domain/scorer_statistics.dart';
import 'package:dart_tournament_manager/features/statistics/domain/tournament_player_statistics.dart';
import 'package:dart_tournament_manager/features/statistics/presentation/player_profile_page.dart';
import 'package:dart_tournament_manager/features/statistics/presentation/tournament_statistics_view.dart';
import 'package:dart_tournament_manager/features/tournaments/data/tournament_storage.dart';

class _TestPaths extends PathProviderPlatform {
  _TestPaths(this.path);
  final String path;
  @override
  Future<String> getApplicationSupportPath() async => path;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  const previewFont = String.fromEnvironment('LAYOUT_PREVIEW_FONT');
  setUpAll(() async {
    if (previewFont.isNotEmpty) {
      final loader = FontLoader('Roboto')
        ..addFont(
          File(
            previewFont,
          ).readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
        );
      await loader.load();
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    }
  });
  for (final width in [360.0, 800.0, 1440.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('Pages at width $width and text $scale', (tester) async {
        final directory = Directory.systemTemp.createTempSync(
          'responsive_pages_',
        );
        final previous = PathProviderPlatform.instance;
        PathProviderPlatform.instance = _TestPaths(directory.path);
        addTearDown(() {
          PathProviderPlatform.instance = previous;
          directory.deleteSync(recursive: true);
        });
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(width, 800);
        addTearDown(tester.view.reset);
        final profileRepository = PlayerStatisticsRepository(
          storage: TournamentStorage(
            file: File('${directory.path}/statistics.json'),
          ),
        );
        await tester.runAsync(
          () => profileRepository.save(
            SavedScorerMatch(
              id: 'preview',
              accountId: 'test-account',
              playedAt: DateTime(2026, 10, 1),
              playerIndex: 0,
              names: ['Anna Beispiel', 'Ben Beispiel'],
              startScores: [40, 40],
              standard501Rules: true,
              doubleOut: true,
              winner: 0,
              visits: const [
                ScorerVisit(
                  player: 0,
                  leg: 0,
                  starter: 0,
                  points: 40,
                  darts: 1,
                  remaining: 0,
                  bust: false,
                  checkoutAttempts: 1,
                ),
              ],
            ),
          ),
        );
        for (final page in <Widget>[
          rankingFixture(),
          const CalendarPreview(),
          const AppointmentEditorPreview(),
          const TournamentEloPreview(),
          const RankingAdminPreview(),
          const LiveRankingPreview(),
          const MemberProfilePreview(),
          const TournamentImportPreview(),
          const PlayerPickerCreationPreview(),
          const CommunityTrendsPreview(),
          const ResultsStatisticsPreview(),
          const CommunityHighlightsPreview(),
          const HighlightEditorPreview(),
          const CommunityStatisticsPreview(),
          const CommunityPlayerStatisticsPreview(),
          const PlayerAnalyticsPreview(),
          const CommunityAnalyticsPreview(),
          const MetricAnalyticsPreview(),
          PlayerProfilePage(
            account: AccountUser(
              id: 'test-account',
              username: 'Anna',
              displayName: 'Anna Beispiel',
              email: 'anna@example.test',
              avatarUrl: null,
              createdAt: DateTime(2026),
              updatedAt: DateTime(2026),
              lastLogin: null,
              isActive: true,
            ),
            repository: profileRepository,
          ),
          Scaffold(
            body: TournamentStatisticsView(
              rows: [
                TournamentPlayerStatistics(
                    'anna',
                    'Anna mit einem besonders langen Spielernamen',
                  )
                  ..matches = 5
                  ..wins = 3
                  ..losses = 2
                  ..legsFor = 12
                  ..legsAgainst = 7
                  ..tournaments.add('cup'),
              ],
            ),
          ),
          const HomePage(),
          const TournamentHomePage(),
          const PlayersPage(),
          CommunityPage(
            accountStore: LocalAccountSessionStore(
              LocalAppDatabase(baseDirectory: directory),
            ),
          ),
          const DevToolsPage(),
          const ScorerPage(),
          for (final mode in ScorerOpponents.values)
            ScorerSetupPage(opponents: mode),
          const ScorerJoinPage(),
          CommunityRoleEditor(
            grantable: CommunityPermissions(
              CommunityPermission.values.map((p) => p.key),
            ),
          ),
          CommunityProfilePage(
            community: Community(
              id: 'club',
              name: 'Dartverein am Wochenende',
              description:
                  'Unsere Community für gemeinsame Turniere und gesellige Dartabende.',
              inviteCode: '',
              ownerUserId: 'owner',
              createdAt: DateTime(2026),
            ),
            repository: RolePreviewMembers(),
          ),
          CommunityRolesPage(
            community: Community(
              id: 'club',
              name: 'Dartverein',
              description: '',
              inviteCode: '',
              ownerUserId: 'owner',
              createdAt: DateTime(2026),
            ),
            membersRepository: RolePreviewMembers(),
            access: RolePreviewAccess(),
          ),
          const CheckoutPage(),
          const AutoscoringPage(),
          const AutoscoreDemoPage(),
          const BotSettingsPage(),
          TournamentResultsPage(
            tournament: CreatedTournament(
              name: 'Sommerturnier mit einem langen Namen',
              players: List.generate(
                3,
                (i) => TournamentPlayer(
                  name: 'Spieler mit langem Namen $i',
                  isGenerated: true,
                ),
              ),
              stages: [],
              runStages: [],
            ),
          ),
          const SettingsPage(),
          CommunityRankingHistoryPage(
            entry:
                CommunityEloEntry(
                    player: CommunityMember(
                      userId: 'elo-preview',
                      displayName: 'Anna Beispiel',
                      role: 'member',
                      joinedAt: DateTime(2026),
                    ),
                    rating: 1021,
                  )
                  ..matches = 3
                  ..wins = 2
                  ..losses = 1,
            history: [
              for (final (delta, rating) in [
                (16, 1016),
                (-20, 996),
                (25, 1021),
              ])
                CommunityEloHistoryItem(
                  playedAt: DateTime(2026),
                  tournamentName: 'Vereinsmeisterschaft',
                  opponentName: 'Langer Name des Gegenspielers',
                  score: '3:1',
                  delta: delta,
                  ratingAfter: rating,
                ),
            ],
            currentYearOnly: false,
          ),
          const TournamentCreationPage(),
          const LeagueMatchPage(),
          LeagueMatchPage(
            tournament: CreatedTournament(
              name: 'Liga: Heim gegen Gast',
              players: [],
              stages: [],
              runStages: [],
              leagueMatch: LeagueMatch.rhl(
                homeTeam: 'Heim',
                awayTeam: 'Gast',
                homePlayers: ['Anna', 'Lena', 'Jan', 'Tom'],
                awayPlayers: ['Ben', 'Max', 'Lisa', 'Mia'],
              ),
            ),
          ),
          Scaffold(
            body: SafeArea(
              child: SingleChildScrollView(
                child: TeamParticipantList(
                  players: [
                    TournamentPlayer.team([
                      TournamentPlayer.generated(1),
                      TournamentPlayer.generated(2),
                    ]),
                    TournamentPlayer.generated(3),
                  ],
                  onRename: (_) {},
                  onRemove: (_) {},
                  onMerge: (_, _) {},
                  onSplit: (_) {},
                ),
              ),
            ),
          ),
          ScorerMatchPage(
            settings: ScorerSettings(
              participants: const [
                ScorerParticipant('Team Anna', members: ['Anna', 'Lena']),
                ScorerParticipant('Team Ben', members: ['Ben', 'Tom', 'Jan']),
              ],
            ),
          ),
        ]) {
          final previewKey = GlobalKey();
          await tester.runAsync(() async {
            await tester.pumpWidget(
              MaterialApp(
                theme: buildDartTournamentTheme(),
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!,
                ),
                home: RepaintBoundary(key: previewKey, child: page),
              ),
            );
            await StorageAccess.run(() async {});
            if (page is PlayerProfilePage) {
              for (var attempt = 0; attempt < 100; attempt++) {
                await tester.pump();
                if (find.byType(CircularProgressIndicator).evaluate().isEmpty) {
                  break;
                }
                await Future<void>.delayed(const Duration(milliseconds: 10));
              }
            }
          });
          await tester.pumpAndSettle();
          expect(
            tester.takeException(),
            isNull,
            reason: '${page.runtimeType} initial',
          );
          if (page is SettingsPage && width == 1440 && scale == 1) {
            await tester.enterText(find.byType(TextFormField).first, '42');
            tester.view.physicalSize = const Size(360, 800);
            await tester.pumpAndSettle();
            expect(find.text('42'), findsOneWidget);
            await tester.tap(find.byType(DropdownButtonFormField<int>));
            await tester.pumpAndSettle();
            await tester.tap(find.text('Datensicherung').last);
            await tester.pumpAndSettle();
            tester.view.physicalSize = Size(width, 800);
            await tester.pumpAndSettle();
            await tester.tap(find.text('Passende Turnierform').first);
            await tester.pumpAndSettle();
            expect(find.text('42'), findsOneWidget);
            expect(tester.takeException(), isNull);
          }
          if (previewFont.isNotEmpty) {
            await tester.runAsync(() async {
              final boundary =
                  previewKey.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary;
              final picture = await boundary.toImage();
              final bytes = await picture.toByteData(
                format: ui.ImageByteFormat.png,
              );
              final file = File(
                'build/layout_previews/${page.runtimeType}${page is ScorerSetupPage ? "_${page.opponents.name}" : ""}_${width}_$scale.png',
              );
              await file.parent.create(recursive: true);
              await file.writeAsBytes(bytes!.buffer.asUint8List());
              picture.dispose();
            });
          }
          if (page is PlayerProfilePage) {
            expect(find.byType(PlayerAnalyticsPage), findsOneWidget);
            expect(find.text('Ausführliches Statistik-Cockpit'), findsNothing);
            expect(find.text('Scorer-Statistiken'), findsNothing);
            await tester.scrollUntilVisible(find.text('Zeitraum wählen'), 200);
            await Scrollable.ensureVisible(
              tester.element(find.text('Zeitraum wählen')),
              alignment: .5,
            );
            await tester.pumpAndSettle();
            await tester.tap(find.text('Zeitraum wählen'));
            await tester.pumpAndSettle();
            expect(find.byType(StatisticsDateDialog), findsOneWidget);
            await tester.enterText(
              find.byType(TextFormField).first,
              '01.01.1971',
            );
            await tester.enterText(
              find.byType(TextFormField).last,
              '02.01.1971',
            );
            await tester.tap(find.text('Anwenden'));
            await tester.pumpAndSettle();
            await tester.scrollUntilVisible(
              find.text('Keine Aufnahmen im gewählten Zeitraum.'),
              200,
            );
            expect(find.text('Anna Beispiel · Ben Beispiel'), findsNothing);
            await tester.scrollUntilVisible(find.text('Gesamt'), -200);
            await Scrollable.ensureVisible(
              tester.element(find.text('Gesamt')),
              alignment: .5,
            );
            await tester.pumpAndSettle();
            for (
              var attempt = 0;
              attempt < 5 &&
                  find.text('Gesamt').hitTestable().evaluate().isEmpty;
              attempt++
            ) {
              await tester.drag(
                find.byType(ListView).first,
                const Offset(0, -120),
              );
              await tester.pumpAndSettle();
            }
            await tester.tap(find.text('Gesamt'));
            await tester.pumpAndSettle();
            await tester.scrollUntilVisible(
              find.text('Anna Beispiel · Ben Beispiel'),
              250,
            );
            await Scrollable.ensureVisible(
              tester.element(find.text('Anna Beispiel · Ben Beispiel')),
              alignment: .5,
            );
            await tester.pumpAndSettle();
            await tester.tap(find.text('Anna Beispiel · Ben Beispiel'));
            await tester.pumpAndSettle();
            expect(find.text('Statistik-Cockpit'), findsOneWidget);
            expect(tester.takeException(), isNull);
            await tester.pageBack();
            await tester.pumpAndSettle();
          }
          final scrollables = find.byType(Scrollable);
          if (scrollables.evaluate().isNotEmpty) {
            for (var i = 0; i < 8; i++) {
              await tester.drag(scrollables.first, const Offset(0, -450));
              await tester.runAsync(() async {
                await Future<void>.delayed(Duration.zero);
              });
              try {
                await tester.pumpAndSettle();
              } catch (failure) {
                throw TestFailure('${page.runtimeType} scroll $i: $failure');
              }
              expect(
                tester.takeException(),
                isNull,
                reason: '${page.runtimeType} scroll $i',
              );
            }
          }
          await tester.pumpWidget(const SizedBox());
        }
      });
    }
  }
}
