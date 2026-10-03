import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_tournament_manager/app/app_theme.dart';
import 'package:dart_tournament_manager/features/remote_control/application/remote_client_controller.dart';
import 'package:dart_tournament_manager/features/remote_control/application/remote_host_controller.dart';
import 'package:dart_tournament_manager/features/remote_control/presentation/remote_control_page.dart';
import 'package:dart_tournament_manager/features/remote_control/presentation/remote_device_section.dart';
import 'package:dart_tournament_manager/features/remote_control/presentation/remote_host_surface.dart';

class PreviewHost extends RemoteHostController {
  PreviewHost() {
    addresses = ['192.168.1.20'];
    pairingKey = List.filled(64, 'a').join();
  }
  @override
  bool get enabled => true;
}

class PreviewClient extends RemoteClientController {
  PreviewClient() {
    image = base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+a6nEAAAAASUVORK5CYII=');
    width = 1440; height = 900; viewport = 7; editor = 3; editingText = 'Spieler';
  }
  final messages = <Map<String, dynamic>>[];
  @override
  bool get connected => true;
  @override
  Future<void> send(Map<String, dynamic> message) async { messages.add(message); }
}

Future<Map<String, dynamic>> capture(WidgetTester tester, RemoteHostController host) async {
  await tester.pumpAndSettle();
  final frame = await tester.runAsync(() => host.capture!());
  expect(frame, isNotNull);
  return frame!;
}

void main() {
  const previewFont = String.fromEnvironment('LAYOUT_PREVIEW_FONT');
  setUpAll(() async {
    if (previewFont.isNotEmpty) {
      final loader = FontLoader('Roboto')..addFont(File(previewFont).readAsBytes().then((bytes) => ByteData.sublistView(bytes)));
      await loader.load();
      await (FontLoader('MaterialIcons')..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    }
  });
  testWidgets('remote touches, scrolling, formatted text, stale edits and resize', (tester) async {
    final host = RemoteHostController();
    final text = TextEditingController();
    final second = TextEditingController();
    final scroll = ScrollController();
    var presses = 0, back = 0;
    await tester.pumpWidget(MaterialApp(theme: buildDartTournamentTheme(), builder: (context, child) => RemoteHostSurface(
      controller: host, onBack: () => back++, child: child!), home: Scaffold(body: ListView(
        controller: scroll, children: [
          FilledButton(onPressed: () => presses++, child: const Text('Spiel starten')),
          TextField(controller: text, inputFormatters: [FilteringTextInputFormatter.digitsOnly]),
          TextField(controller: second),
          for (var i = 0; i < 40; i++) SizedBox(height: 60, child: Text('Zeile $i')),
        ]))));
    var frame = await capture(tester, host);
    void touch(String type, Offset point, {int? viewport}) => host.onInput!({
      'type': type, 'viewport': viewport ?? frame['viewport'], 'pointer': 0,
      'x': point.dx / (frame['width'] as num), 'y': point.dy / (frame['height'] as num),
    });
    final button = tester.getCenter(find.text('Spiel starten'));
    touch('down', button); touch('up', button);
    await tester.pump(); expect(presses, 1);
    final field = tester.getCenter(find.byType(TextField).first);
    touch('down', field); touch('up', field);
    frame = await capture(tester, host);
    expect(frame['editingText'], '');
    host.onInput!({'type': 'text', 'viewport': frame['viewport'], 'editor': frame['editor'], 'text': '12a3'});
    await tester.pump(); expect(text.text, '123');
    await tester.tap(find.byType(TextField).last);
    host.onInput!({'type': 'text', 'viewport': frame['viewport'], 'editor': frame['editor'], 'text': 'Veraltet'});
    expect(second.text, isEmpty);
    frame = await capture(tester, host);
    host.onInput!({'type': 'back', 'viewport': frame['viewport']}); expect(back, 1);
    host.onInput!({'type': 'scroll', 'viewport': frame['viewport'], 'pointer': 0, 'x': .5, 'y': .6, 'dy': 200});
    await tester.pumpAndSettle(); expect(scroll.offset, greaterThan(0));
    final oldViewport = frame['viewport'] as int;
    await tester.binding.setSurfaceSize(const Size(360, 800));
    frame = await capture(tester, host);
    expect(frame['viewport'], isNot(oldViewport));
    touch('down', button, viewport: oldViewport); touch('up', button, viewport: oldViewport);
    await tester.pump(); expect(presses, 1);
    expect(text.text, '123');
    await tester.pumpWidget(const SizedBox());
    host.dispose(); text.dispose(); second.dispose(); scroll.dispose();
    await tester.binding.setSurfaceSize(null);
  });

  for (final size in [const Size(360, 800), const Size(800, 600), const Size(1440, 900)]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('remote layouts $size at $scale', (tester) async {
        await tester.binding.setSurfaceSize(size);
        final host = PreviewHost();
        final client = PreviewClient();
        final preview = GlobalKey();
        Widget app(Widget child) => RemoteHostScope(controller: host, child: MaterialApp(
          theme: buildDartTournamentTheme(),
          builder: (context, child) => MediaQuery(data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)), child: child!),
          home: RepaintBoundary(key: preview, child: child)));
        await tester.pumpWidget(app(const Scaffold(body: SingleChildScrollView(child: RemoteDeviceSection()))));
        await tester.pumpAndSettle(); expect(tester.takeException(), isNull);
        await tester.pumpWidget(app(const RemoteControlPage(address: '192.168.1.20')));
        await tester.pumpAndSettle(); expect(tester.takeException(), isNull);
        if (scale == 1 && (size.width == 360 || size.width == 1440)) {
          await tester.runAsync(() async {
            final boundary = preview.currentContext!.findRenderObject() as RenderRepaintBoundary;
            final image = await boundary.toImage();
            final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
            image.dispose();
            final file = File('build/layout_previews/remote_${size.width.toInt()}.png');
            await file.parent.create(recursive: true);
            await file.writeAsBytes(bytes!.buffer.asUint8List());
          });
        }
        // Use a fresh page so its injected live client is initialized.
        await tester.pumpWidget(app(RemoteControlPage(key: UniqueKey(), controller: client)));
        await tester.pumpAndSettle(); expect(tester.takeException(), isNull);
        await tester.tap(find.text('Text eingeben'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), 'Neuer Spieler');
        await tester.ensureVisible(find.text('Übernehmen'));
        await tester.tap(find.text('Übernehmen'));
        await tester.pumpAndSettle();
        expect(client.messages.single['text'], 'Neuer Spieler');
        expect(client.messages.single['editor'], 3);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox()); await tester.pump(const Duration(milliseconds: 350));
        host.dispose(); client.dispose(); await tester.binding.setSurfaceSize(null);
      });
    }
  }
}
