import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dart_tournament_manager/features/autoscoring/data/autoscore_setup_store.dart';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_tournament_manager/features/autoscoring/application/autoscoring_controller.dart';
import 'package:dart_tournament_manager/features/autoscoring/domain/board_geometry.dart';
import 'package:dart_tournament_manager/features/scorer/domain/x01/x01_models.dart';
import 'package:dart_tournament_manager/app/app_theme.dart';
import 'package:dart_tournament_manager/features/autoscoring/application/autoscore_demo_controller.dart';
import 'package:dart_tournament_manager/features/autoscoring/presentation/autoscore_demo_page.dart';
import 'package:dart_tournament_manager/features/autoscoring/presentation/autoscoring_page.dart';
import 'package:dart_tournament_manager/features/scorer/domain/x01/x01_rules.dart';
import 'package:dart_tournament_manager/features/autoscoring/data/autoscore_diagnostic_export.dart';

class _CameraController extends AutoscoringController {
  @override
  Future<void> discover() async {}
  void detect() {
    pending = const FusedHit(Point(0, -103), 0, 3);
    if (automaticCounting) {
      final result = BoardGeometry.score(pending!.point);
      accept(result);
      onAutomaticThrow?.call(result);
    }
    notifyListeners();
  }

  @override
  void accept(DartThrowResult result) {
    this.throws.add(result);
    pending = null;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('xyz.luan/audioplayers.global/events'),
          (_) async => null,
        );
  });
  testWidgets(
    'Correction archive action fits a narrow screen with large text',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(360, 800);
      addTearDown(tester.view.reset);
      final controller = AutoscoreDemoController();
      final cameras = _CameraController();
      addTearDown(controller.dispose);
      addTearDown(cameras.dispose);
      controller.add(
        const X01Rules().createTriple(20),
        evidence: AutoscoreEvidence([
          AutoscoreCameraEvidence(Uint8List(0), null, null, const {}),
        ], const {}),
      );
      controller.review(0, const X01Rules().createSingle(20));
      controller.history.single.diagnosticPath = 'test.zip';
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: AutoscoreDemoPage(
            controller: controller,
            cameraController: cameras,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Diagnose-ZIP speichern').hitTestable(),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Diagnose-ZIP speichern').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  const previewFont = String.fromEnvironment('LAYOUT_PREVIEW_FONT');
  setUpAll(() async {
    if (previewFont.isNotEmpty) {
      await (FontLoader('Roboto')..addFont(
            File(previewFont).readAsBytes().then(ByteData.sublistView),
          ))
          .load();
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    }
  });
  testWidgets('Menu opens Autoscorer settings and camera workbench', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await AutoscoreSetupStore.instance.load();
    AutoscoreSetupStore.instance.saveSettings(caller: false, sounds: false);
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: AutoscoreTesterMenuCard())),
    );
    await tester.tap(find.text('Autoscorer'));
    await tester.pumpAndSettle();
    final open = find.text('Kameras, Kalibrierung und Erkennung öffnen');
    await tester.scrollUntilVisible(
      open,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(open);
    await tester.pumpAndSettle();
    expect(find.text('Autoscorer · Kameratest'), findsOneWidget);
    expect(find.byType(AutoscoringPage), findsOneWidget);
    expect(find.text('Beispieltreffer simulieren'), findsNothing);
    final page = tester.widget<AutoscoringPage>(find.byType(AutoscoringPage));
    expect(page.onThrow!(X01Rules().createTriple(20)), isTrue);
    await tester.pumpAndSettle();
    expect(find.text('60 Punkte'), findsOneWidget);
    expect(page.automaticCounting, isTrue);
    expect(
      find.text('Automatisch gezählter USB-Kameratreffer'),
      findsOneWidget,
    );
    page.onBoardCleared!();
    await tester.pumpAndSettle();
    expect(find.text('0 Punkte'), findsOneWidget);
    expect(find.text('60 Punkte'), findsNothing);
    expect(page.onThrow!(X01Rules().createDouble(20)), isTrue);
    await tester.pumpAndSettle();
    expect(find.text('40 Punkte'), findsOneWidget);
  });
  for (final size in [
    const Size(360, 800),
    const Size(800, 600),
    const Size(1440, 900),
  ]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('Autoscore demo $size text $scale', (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = size;
        addTearDown(tester.view.reset);
        final controller = AutoscoreDemoController();
        addTearDown(controller.dispose);
        final cameras = _CameraController();
        addTearDown(cameras.dispose);
        final boundary = GlobalKey();
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
              key: boundary,
              child: AutoscoreDemoPage(
                controller: controller,
                cameraController: cameras,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Beispieltreffer simulieren'), findsNothing);
        cameras.detect();
        await tester.pump();
        expect(find.text('Treffer bestätigen'), findsNothing);
        await tester.pumpAndSettle();
        expect(controller.totalPoints, 60);
        expect(controller.throws.single.scoredPoints, 60);
        expect(cameras.pending, isNull);
        await tester.scrollUntilVisible(
          find.text('Korrigieren').hitTestable(),
          150,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(find.text('Korrigieren'));
        await tester.pumpAndSettle();
        expect(find.text('Treffer korrigieren'), findsOneWidget);
        await tester.ensureVisible(find.text('Fehlwurf'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Fehlwurf'));
        await tester.pumpAndSettle();
        expect(controller.totalPoints, 0);
        expect(controller.accuracyPercent, 0);
        expect(find.text('Richtig erkannt'), findsNothing);
        expect(tester.takeException(), isNull);
        if (previewFont.isNotEmpty && scale == 1) {
          tester
              .state<ScrollableState>(find.byType(Scrollable).first)
              .position
              .jumpTo(0);
          await tester.pumpAndSettle();
          await tester.runAsync(() async {
            final render =
                boundary.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            final picture = await render.toImage(pixelRatio: 1);
            final bytes = await picture.toByteData(
              format: ui.ImageByteFormat.png,
            );
            final file = File(
              'build/layout_previews/autoscore_demo_${size.width.toInt()}.png',
            );
            await file.parent.create(recursive: true);
            await file.writeAsBytes(bytes!.buffer.asUint8List());
            picture.dispose();
          });
        }
        tester
            .state<ScrollableState>(find.byType(Scrollable).first)
            .position
            .jumpTo(0);
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.text('Punktestand zurücksetzen').hitTestable(),
          150,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(find.text('Punktestand zurücksetzen'));
        await tester.pumpAndSettle();
        expect(controller.throws, isEmpty);
        expect(controller.totalPoints, 0);
        await tester.pumpWidget(const SizedBox());
      });
    }
  }
}
