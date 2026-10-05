import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_tournament_manager/app/app_theme.dart';
import 'package:dart_tournament_manager/features/communities/presentation/widgets/community_menu.dart';
import 'package:dart_tournament_manager/shared/widgets/sport_menu.dart';

void main() {
  const font = String.fromEnvironment('LAYOUT_PREVIEW_FONT');
  setUpAll(() async {
    if (font.isNotEmpty) {
      await (FontLoader('Roboto')..addFont(
            File(
              font,
            ).readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
          ))
          .load();
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
      testWidgets('Every community menu action $size text $scale', (
        tester,
      ) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = size;
        addTearDown(tester.view.reset);
        final selected = <CommunityArea>[];
        final preview = GlobalKey();
        await tester.pumpWidget(
          MaterialApp(
            theme: buildDartTournamentTheme(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: RepaintBoundary(
              key: preview,
              child: Scaffold(
                body: CommunityMenu(
                  description: 'Gemeinsam am Oche.',
                  onSelected: selected.add,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        if (font.isNotEmpty) {
          await tester.runAsync(() async {
            final boundary =
                preview.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            final picture = await boundary.toImage();
            final bytes = await picture.toByteData(
              format: ui.ImageByteFormat.png,
            );
            final output = File(
              'build/layout_previews/community_menu_${size.width}_$scale.png',
            );
            await output.parent.create(recursive: true);
            await output.writeAsBytes(bytes!.buffer.asUint8List());
            picture.dispose();
          });
        }
        for (final area in [
          CommunityArea.tournaments,
          CommunityArea.calendar,
          CommunityArea.members,
          CommunityArea.ranking,
          CommunityArea.statistics,
        ]) {
          await tester.scrollUntilVisible(
            find.text(area.title),
            150,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.pumpAndSettle();
          await tester.tap(find.text(area.title));
        }
        await tester.scrollUntilVisible(
          find.text('Community verwalten'),
          150,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Community verwalten'));
        await tester.pumpAndSettle();
        // Resize while expanded; the administrative entries remain available.
        tester.view.physicalSize = size.width == 360
            ? const Size(1440, 900)
            : const Size(360, 800);
        await tester.pumpAndSettle();
        for (final area in [
          CommunityArea.invitations,
          CommunityArea.devices,
          CommunityArea.roles,
          CommunityArea.profile,
        ]) {
          await tester.scrollUntilVisible(
            find.text(area.title),
            150,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.pumpAndSettle();
          await tester.tap(find.text(area.title));
        }
        expect(selected.toSet(), CommunityArea.values.toSet());
        expect(tester.takeException(), isNull);
      });
    }
  }
  testWidgets('Overflow actions honour disabled commands', (tester) async {
    var called = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildDartTournamentTheme(),
        home: Scaffold(
          body: SportActionsMenu(
            actions: [
              SportMenuAction(
                label: 'Öffnen',
                icon: Icons.open_in_new,
                onTap: () => called = true,
              ),
              const SportMenuAction(
                label: 'Gesperrt',
                icon: Icons.lock,
                onTap: null,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.tap(find.text('Weitere Aktionen'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<PopupMenuItem<int>>(
            find.widgetWithText(PopupMenuItem<int>, 'Gesperrt'),
          )
          .enabled,
      false,
    );
    await tester.tap(find.text('Öffnen'));
    await tester.pumpAndSettle();
    expect(called, true);
  });
}
