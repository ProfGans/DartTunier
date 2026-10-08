import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:dart_tournament_manager/shared/persistence/storage_access.dart';
import 'community_calendar_test.dart' show AppointmentEditorPreview;
import 'community_highlights_test.dart' show HighlightEditorPreview;
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dart_tournament_manager/app/app_theme.dart';
import 'package:dart_tournament_manager/shared/widgets/adaptive_content.dart';
import 'package:dart_tournament_manager/shared/widgets/sport_settings_section.dart';
import 'package:dart_tournament_manager/features/scorer/presentation/bot_settings_page.dart';
import 'package:dart_tournament_manager/features/settings/presentation/settings_page.dart';
import 'package:dart_tournament_manager/features/league/presentation/league_match_page.dart';
import 'package:dart_tournament_manager/features/communities/presentation/community_roles_page.dart';
import 'package:dart_tournament_manager/features/communities/domain/community_permissions.dart';

class _MenuPaths extends PathProviderPlatform {
  _MenuPaths(this.path);
  final String path;
  @override
  Future<String> getApplicationSupportPath() async => path;
}

void main() {
  const font = String.fromEnvironment('LAYOUT_PREVIEW_FONT');
  setUp(() => SharedPreferences.setMockInitialValues({}));
  setUpAll(() async {
    if (font.isNotEmpty) {
      await (FontLoader(
        'Roboto',
      )..addFont(File(font).readAsBytes().then(ByteData.sublistView))).load();
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    }
  });

  final pages = <String, (Widget Function(), List<String>)>{
    'Kalender': (() => const AppointmentEditorPreview(), ['Ort & Hinweise']),
    'Highlights': (() => const HighlightEditorPreview(), ['Zuordnung & Notiz']),
    'Bots': (
      () => const BotSettingsPage(),
      ['Feinabstimmung', 'Anzeige & Kamera'],
    ),
    'Planung': (
      () => const SettingsPage(),
      ['Minuten pro Leg', 'Bewertung (Strafpunkte)', 'So wird gerechnet'],
    ),
    'Liga': (
      () => const LeagueMatchPage(),
      ['Geräte zuordnen', 'Heimteam & Aufstellung', 'Gastteam & Aufstellung'],
    ),
    'Rollen': (
      () => CommunityRoleEditor(
        grantable: CommunityPermissions(
          CommunityPermission.values.map((p) => p.key),
        ),
      ),
      ['Turniere', 'Community & Mitglieder', 'Geräte, Ranglisten & Highlights'],
    ),
  };
  for (final size in [
    const Size(360, 800),
    const Size(800, 600),
    const Size(1440, 900),
  ]) {
    for (final scale in [1.0, 2.0]) {
      for (final entry in pages.entries) {
        testWidgets('${entry.key} compact and expanded $size text $scale', (
          tester,
        ) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = size;
          addTearDown(tester.view.reset);
          final directory = Directory.systemTemp.createTempSync('menu_layout_');
          final previousPaths = PathProviderPlatform.instance;
          PathProviderPlatform.instance = _MenuPaths(directory.path);
          addTearDown(() {
            PathProviderPlatform.instance = previousPaths;
            directory.deleteSync(recursive: true);
          });
          final boundary = GlobalKey();
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
                home: RepaintBoundary(key: boundary, child: entry.value.$1()),
              ),
            );
            await StorageAccess.run(() async {});
            await Future<void>.delayed(const Duration(milliseconds: 100));
          });
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          if (font.isNotEmpty && scale == 1) {
            await tester.runAsync(() async {
              final render =
                  boundary.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary;
              final image = await render.toImage();
              final bytes = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              final file = File(
                'build/layout_previews/menu_${entry.key}_${size.width.toInt()}.png',
              );
              await file.parent.create(recursive: true);
              await file.writeAsBytes(bytes!.buffer.asUint8List());
              image.dispose();
            });
          }
          for (final title in entry.value.$2) {
            await tester.scrollUntilVisible(
              find.text(title).hitTestable(),
              180,
              scrollable: find.byType(Scrollable).first,
              maxScrolls: 80,
            );
            await tester.tap(find.text(title));
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
          }
          await tester.drag(
            find.byType(Scrollable).first,
            const Offset(0, -500),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        });
      }
    }
  }

  testWidgets('Disclosure and text survive scrolling and rotation', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 800);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AdaptiveContentList(
            children: [
              const SportSettingsSection(
                title: 'Optionen',
                summary: 'Bei Bedarf öffnen',
                children: [
                  TextField(decoration: InputDecoration(labelText: 'Notiz')),
                ],
              ),
              const SizedBox(height: 1500),
              TextButton(onPressed: () {}, child: const Text('Ende')),
            ],
          ),
        ),
      ),
    );
    expect(find.byType(TextField), findsNothing);
    await tester.tap(find.text('Optionen'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Meine Eingabe');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Optionen'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Ende'),
      350,
      scrollable: find.byType(Scrollable).first,
    );
    tester.view.physicalSize = const Size(1440, 900);
    await tester.pumpAndSettle();
    tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position
        .jumpTo(0);
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);
    await tester.tap(find.text('Optionen'));
    await tester.pumpAndSettle();
    expect(find.text('Meine Eingabe'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
