import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dart_tournament_manager/features/autoscoring/data/autoscore_setup_store.dart';
import 'package:dart_tournament_manager/features/autoscoring/presentation/autoscorer_page.dart';

class AutoscorerPreview extends StatefulWidget {
  const AutoscorerPreview({super.key});
  @override
  State<AutoscorerPreview> createState() => _AutoscorerPreviewState();
}

class _AutoscorerPreviewState extends State<AutoscorerPreview> {
  final store = AutoscoreSetupStore();
  @override
  void initState() {
    super.initState();
    store.load().then((_) {
      if (!mounted || !store.loaded) return;
      store.rename('Wohnzimmer · drei USB-Kameras am gedrehten Board');
      final a = store.record(), b = store.record(estimated: true);
      store.review(a, corrected: false);
      store.review(b, corrected: true);
    });
  }

  @override
  void dispose() {
    store.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AutoscorerPage(store: store);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
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
  for (final size in [
    const Size(360, 800),
    const Size(800, 600),
    const Size(1440, 900),
  ]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('Autoscorer setup page at $size and text $scale', (
        tester,
      ) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = size;
        addTearDown(tester.view.reset);
        final key = GlobalKey();
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: RepaintBoundary(key: key, child: const AutoscorerPreview()),
          ),
        );
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.text('Genauigkeit: 50.0 %'),
          100,
          scrollable: find.byType(Scrollable).first,
        );
        expect(tester.takeException(), isNull);
        if (font.isNotEmpty && scale == 1) {
          tester
              .state<ScrollableState>(find.byType(Scrollable).first)
              .position
              .jumpTo(0);
          await tester.pumpAndSettle();
          await tester.runAsync(() async {
            final boundary =
                key.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            final image = await boundary.toImage();
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            final file = File(
              'build/layout_previews/autoscorer_setups_${size.width.toInt()}.png',
            );
            file.parent.createSync(recursive: true);
            file.writeAsBytesSync(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
        await tester.scrollUntilVisible(
          find.text('Kameras, Kalibrierung und Erkennung öffnen'),
          150,
          scrollable: find.byType(Scrollable).first,
        );
        expect(tester.takeException(), isNull);
        if (scale == 2) {
          tester
              .state<ScrollableState>(find.byType(Scrollable).first)
              .position
              .jumpTo(0);
          await tester.pumpAndSettle();
          await tester.tap(find.text('Neues Setup'));
          await tester.pumpAndSettle();
          await tester.enterText(
            find.byType(TextFormField),
            'Zweiter Aufbau mit langem deutschen Namen',
          );
          await tester.tap(find.text('Speichern'));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }
      });
    }
  }
  testWidgets('Create and select named setups with isolated statistics', (
    tester,
  ) async {
    final store = AutoscoreSetupStore();
    await store.load();
    final token = store.record();
    store.review(token, corrected: false);
    await tester.pumpWidget(MaterialApp(home: AutoscorerPage(store: store)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Neues Setup'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'Garage');
    await tester.tap(find.text('Speichern'));
    await tester.pumpAndSettle();
    expect(store.active.name, 'Garage');
    expect(store.active.total, 0);
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Standard-Setup').last);
    await tester.pumpAndSettle();
    expect(store.active.accuracy, 100);
    await store.flush();
    await tester.pumpWidget(const SizedBox());
    store.dispose();
  });
}
