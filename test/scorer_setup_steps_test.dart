import 'package:dart_tournament_manager/features/scorer/domain/scorer_settings.dart';
import 'package:dart_tournament_manager/features/scorer/domain/x01/x01_models.dart';
import 'package:dart_tournament_manager/features/scorer/data/repositories/checkout_route_repository.dart';
import 'support/scorer_lobby_fake.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_tournament_manager/app/app_theme.dart';
import 'package:dart_tournament_manager/features/scorer/presentation/scorer_setup_page.dart';
import 'package:dart_tournament_manager/features/scorer/presentation/widgets/scorer_setup_wizard.dart';
import 'package:dart_tournament_manager/features/scorer/domain/scorer_opponents.dart';
import 'support/scorer_setup_navigation.dart';

void main() {
  const font = String.fromEnvironment('LAYOUT_PREVIEW_FONT');
  setUpAll(() async {
    if (font.isNotEmpty) {
      await (FontLoader('Roboto')..addFont(
            File(font).readAsBytes().then((b) => ByteData.sublistView(b)),
          ))
          .load();
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    }
  });
  testWidgets('advanced rules and handicap reach remote start unchanged', (
    tester,
  ) async {
    await tester.runAsync(() => CheckoutRouteRepository.instance.initialize());
    ScorerSettings? actual;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildDartTournamentTheme(),
        home: ScorerSetupPage(
          opponents: ScorerOpponents.players,
          lobbyRepository: FakeScorerLobbyRepository(),
          remoteStart: (settings) async {
            actual = settings;
            return false;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Eigene Startpunkte').first);
    await tester.pumpAndSettle();
    final handicap = find.widgetWithText(
      TextFormField,
      'Eigene Startpunkte (optional)',
    );
    await tester.scrollUntilVisible(
      handicap,
      150,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(handicap, '201');
    await scorerSetupNext(tester);
    await tester.scrollUntilVisible(
      find.text('Weitere Spielregeln'),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    await Scrollable.ensureVisible(
      tester.element(find.text('Weitere Spielregeln')),
      alignment: .5,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Weitere Spielregeln'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byType(DropdownButtonFormField<StartRequirement>),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    await Scrollable.ensureVisible(
      tester.element(find.byType(DropdownButtonFormField<StartRequirement>)),
      alignment: .5,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<StartRequirement>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Double In').last);
    await tester.pumpAndSettle();
    final sets = find.widgetWithText(TextFormField, 'Best of Sets');
    await tester.scrollUntilVisible(
      sets,
      150,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(sets, '3');
    await scorerSetupNext(tester);
    await tester.scrollUntilVisible(
      find.text('Spiel starten'),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    await Scrollable.ensureVisible(
      tester.element(find.text('Spiel starten')),
      alignment: .5,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Spiel starten'));
    await tester.pumpAndSettle();
    expect(actual, isNotNull);
    expect(actual!.participants.first.startScore, 201);
    expect(actual!.bestOfSets, 3);
    expect(actual!.startRequirement, StartRequirement.doubleIn);
    expect(tester.takeException(), isNull);
  });
  for (final size in [
    const Size(360, 800),
    const Size(800, 600),
    const Size(1440, 900),
  ]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('setup steps preserve draft $size $scale', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
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
              child: const ScorerSetupPage(opponents: ScorerOpponents.players),
            ),
          ),
        );
        await tester.pumpAndSettle();
        Future<void> capture(int step) async {
          if (font.isEmpty) return;
          await tester.runAsync(() async {
            final image =
                await (preview.currentContext!.findRenderObject()
                        as RenderRepaintBoundary)
                    .toImage();
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            final file = File(
              'build/layout_previews/ScorerWizard_${size.width}_${scale}_$step.png',
            );
            await file.parent.create(recursive: true);
            await file.writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }

        await capture(0);
        final name = find.widgetWithText(TextFormField, 'Teilnehmer 1 · Name');
        await tester.scrollUntilVisible(
          name,
          150,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.enterText(name, 'Anna');
        await scorerSetupNext(tester);
        final points = find.widgetWithText(TextFormField, 'Startpunkte');
        await tester.scrollUntilVisible(
          points,
          150,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.enterText(points, '0');
        await scorerSetupNext(tester);
        expect(
          tester.widget<ScorerSetupWizard>(find.byType(ScorerSetupWizard)).step,
          1,
        );
        await tester.scrollUntilVisible(
          points,
          -150,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.enterText(points, '301');
        await tester.pump();
        await capture(1);
        await scorerSetupNext(tester);
        expect(find.text('Anna'), findsOneWidget);
        expect(find.textContaining('301 Punkte'), findsOneWidget);
        await capture(2);
        await tester.tap(find.byTooltip('Vorheriger Schritt'));
        await tester.pumpAndSettle();
        tester.view.physicalSize = Size(size.height, size.width);
        await tester.pumpAndSettle();
        expect(tester.widget<TextFormField>(points).controller!.text, '301');
        await tester.tap(find.byTooltip('Vorheriger Schritt'));
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          name,
          150,
          scrollable: find.byType(Scrollable).first,
        );
        expect(tester.widget<TextFormField>(name).controller!.text, 'Anna');
        expect(tester.takeException(), isNull);
      });
    }
  }
}
