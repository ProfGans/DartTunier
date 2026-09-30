import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_tournament_manager/tournament_workspace.dart';
import 'package:dart_tournament_manager/features/settings/presentation/settings_page.dart';
import 'package:dart_tournament_manager/features/scorer/presentation/scorer_match_page.dart';
import 'package:dart_tournament_manager/features/scorer/domain/scorer_settings.dart';
import 'package:dart_tournament_manager/shared/persistence/storage_access.dart';
import 'package:dart_tournament_manager/app/app_theme.dart';
import 'package:dart_tournament_manager/features/communities/presentation/community_page.dart';
import 'package:dart_tournament_manager/features/players/presentation/players_page.dart';
import 'package:dart_tournament_manager/features/dev_tools/presentation/dev_tools_page.dart';
import 'package:dart_tournament_manager/features/scorer/presentation/scorer_page.dart';
import 'package:dart_tournament_manager/features/scorer/presentation/checkout_page.dart';
import 'package:dart_tournament_manager/features/scorer/presentation/bot_settings_page.dart';
import 'package:dart_tournament_manager/features/tournaments/presentation/pages/tournament_results_page.dart';
import 'package:dart_tournament_manager/features/tournaments/domain/tournament_models.dart';
import 'package:dart_tournament_manager/features/tournaments/data/app_database.dart';
import 'package:dart_tournament_manager/features/accounts/application/account_session_store.dart';

class _TestPaths extends PathProviderPlatform {
  _TestPaths(this.path);
  final String path;
  @override
  Future<String> getApplicationSupportPath() async => path;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
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
        for (final page in <Widget>[
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
          const CheckoutPage(),
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
          const TournamentCreationPage(),
          ScorerMatchPage(
            settings: ScorerSettings(
              participants: const [
                ScorerParticipant('Anna'),
                ScorerParticipant('Ben'),
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
                'build/layout_previews/${page.runtimeType}_${width}_$scale.png',
              );
              await file.parent.create(recursive: true);
              await file.writeAsBytes(bytes!.buffer.asUint8List());
              picture.dispose();
            });
          }
          final scrollables = find.byType(Scrollable);
          if (scrollables.evaluate().isNotEmpty) {
            for (var i = 0; i < 8; i++) {
              await tester.drag(scrollables.first, const Offset(0, -450));
              await tester.pumpAndSettle();
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
