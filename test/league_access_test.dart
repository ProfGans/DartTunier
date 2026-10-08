import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_tournament_manager/features/league/presentation/league_match_page.dart';
import 'package:dart_tournament_manager/features/tournaments/domain/tournament_access.dart';
import 'package:dart_tournament_manager/features/tournaments/domain/tournament_models.dart';
import 'rhl_league_test.dart' show fixture;

void main() {
  const font = String.fromEnvironment('LAYOUT_PREVIEW_FONT');
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
  for (final size in [
    const Size(360, 800),
    const Size(800, 600),
    const Size(1440, 900),
  ]) {
    for (final scale in [1.0, 2.0]) {
      for (final role in ['viewer', 'reporter', 'director']) {
        testWidgets('RHL $role $size text $scale', (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          final tournament = CreatedTournament(
            name: 'Community-Ligaspiel',
            communityId: 'club',
            players: [],
            stages: [],
            runStages: [],
            leagueMatch: fixture(),
          );
          tournament.leagueMatch!.games.first.score(3, 1);
          final boundary = GlobalKey();
          await tester.pumpWidget(
            MaterialApp(
              home: MediaQuery(
                data: MediaQueryData(
                  size: size,
                  textScaler: TextScaler.linear(scale),
                ),
                child: RepaintBoundary(
                  key: boundary,
                  child: LeagueMatchPage(
                    tournament: tournament,
                    loadAccess: () async => TournamentAccess(
                      canLead: role == 'director',
                      canConfigure: role == 'director',
                      canEnterResults: role != 'viewer',
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(
            find.text('Turnierrechte'),
            role == 'director' ? findsOneWidget : findsNothing,
          );
          if (role == 'director') {
            await tester.scrollUntilVisible(
              find.text('Boards und Geräte'),
              200,
              scrollable: find.byType(Scrollable).first,
            );
            await tester.pumpAndSettle();
            expect(find.text('Boards und Geräte'), findsOneWidget);
          } else {
            expect(find.text('Boards und Geräte'), findsNothing);
          }
          expect(tester.takeException(), isNull);
          if (font.isNotEmpty && role != 'director') {
            await tester.runAsync(() async {
              final image =
                  await (boundary.currentContext!.findRenderObject()
                          as RenderRepaintBoundary)
                      .toImage();
              final bytes = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              final file = File(
                'build/layout_previews/league_${role}_${size.width}_$scale.png',
              );
              await file.parent.create(recursive: true);
              await file.writeAsBytes(bytes!.buffer.asUint8List());
              image.dispose();
            });
          }
          if (role == 'reporter') {
            expect(find.byKey(const ValueKey('league-result-0')), findsNothing);
            await tester.scrollUntilVisible(
              find.byKey(const ValueKey('league-result-1')),
              300,
              scrollable: find.byType(Scrollable).first,
            );
            await tester.pumpAndSettle();
            await tester.ensureVisible(
              find.byKey(const ValueKey('league-result-1')),
            );
            await tester.pumpAndSettle();
            await tester.tap(find.byKey(const ValueKey('league-result-1')));
            await tester.pumpAndSettle();
            expect(find.text('Ergebnis entfernen'), findsNothing);
            expect(find.text('3:2'), findsOneWidget);
            expect(tester.takeException(), isNull);
          }
          await tester.pumpWidget(const SizedBox());
        });
      }
    }
  }
}
