import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_tournament_manager/app/app_theme.dart';
import 'package:dart_tournament_manager/shared/widgets/adaptive_content.dart';
import 'package:dart_tournament_manager/features/devices/domain/app_device.dart';
import 'package:dart_tournament_manager/features/remote_control/application/remote_client_controller.dart';
import 'package:dart_tournament_manager/features/remote_control/application/remote_host_controller.dart';
import 'package:dart_tournament_manager/features/remote_control/presentation/remote_device_section.dart';
import 'package:dart_tournament_manager/features/remote_control/presentation/remote_host_surface.dart';
import 'package:dart_tournament_manager/features/remote_control/presentation/remote_control_page.dart';
import 'package:dart_tournament_manager/features/remote_control/presentation/remote_confirmation_view.dart';
import 'support/remote_control_fakes.dart';

class ConfirmationPreview extends RemoteHostController {
  ConfirmationPreview() { pendingName = 'Handy mit einem langen deutschen Gerätenamen'; }
  bool? answer;
  @override
  void answerConfirmation(bool accept) { answer = accept; }
}
class AccountClientPreview extends RemoteClientController {
  bool _connected = false;
  String? receivedKey, receivedMode;
  @override
  bool get connected => _connected;
  @override
  Future<void> connect(String address, String key, {int port = RemoteHostController.port, String mode = 'code', String name = 'Fernbedienung', bool actions = false}) async {
    receivedKey = key; receivedMode = mode;
    image = base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+a6nEAAAAASUVORK5CYII=');
    width = 800; height = 600; _connected = true; notifyListeners();
  }
}

Future<void> scrollToHit(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 80; i++) {
    if (finder.hitTestable().evaluate().isNotEmpty) return;
    await tester.drag(find.byType(ListView).first, const Offset(0, -250));
    await tester.pumpAndSettle();
  }
  expect(finder.hitTestable(), findsOneWidget);
}

void main() {
  const font = String.fromEnvironment('LAYOUT_PREVIEW_FONT');
  setUpAll(() async {
    if (font.isNotEmpty) {
      await (FontLoader('Roboto')..addFont(File(font).readAsBytes().then(ByteData.sublistView))).load();
      await (FontLoader('MaterialIcons')..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    }
  });
  for (final size in [const Size(360, 800), const Size(800, 600), const Size(1440, 900)]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('confirmation settings and account connection $size text $scale', (tester) async {
        await tester.binding.setSurfaceSize(size);
        final settings = MemoryRemoteSettings();
        final accounts = MemoryRemoteAccounts();
        const other = AppDevice(id: 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb', name: 'Mein anderes Handy mit einem langen deutschen Gerätenamen', platform: 'android');
        final secret = List.filled(64, 'b').join();
        await accounts.publish(other, ['192.168.1.30'], secret);
        final host = RemoteHostController(settingsStorage: settings, accountRepository: accounts);
        await host.initialize(device: remoteTestDevice);
        final preview = GlobalKey();
        Widget app(Widget child) => RemoteHostScope(controller: host, child: MaterialApp(theme: buildDartTournamentTheme(),
          builder: (context, child) => MediaQuery(data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)), child: child!),
          home: RepaintBoundary(key: preview, child: child)));
        Future<void> screenshot(String suffix) async {
          if (scale != 1 || (size.width != 360 && size.width != 1440)) return;
          await tester.runAsync(() async {
            final boundary = preview.currentContext!.findRenderObject() as RenderRepaintBoundary;
            final image = await boundary.toImage();
            final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
            image.dispose();
            final file = File('build/layout_previews/remote_${suffix}_${size.width.toInt()}.png');
            await file.parent.create(recursive: true); await file.writeAsBytes(bytes!.buffer.asUint8List());
          });
        }
        await tester.pumpWidget(app(const Scaffold(body: AdaptiveContentList(children: [RemoteDeviceSection()]))));
        await tester.pumpAndSettle();
        expect(host.requireConfirmation, isFalse);
        await scrollToHit(tester, find.text('Übernahme bestätigen'));
        await tester.tap(find.text('Übernahme bestätigen'));
        await tester.pumpAndSettle();
        expect(settings.value.requireConfirmation, isTrue);
        expect(tester.takeException(), isNull);
        await screenshot('settings');
        await tester.scrollUntilVisible(find.text(other.name), 200);
        expect(find.text(other.name), findsOneWidget);
        final confirmation = ConfirmationPreview();
        await tester.pumpWidget(app(RemoteConfirmationView(controller: confirmation)));
        await tester.pumpAndSettle(); expect(tester.takeException(), isNull);
        await screenshot('confirmation');
        await scrollToHit(tester, find.text('Übernahme erlauben'));
        await tester.tap(find.text('Übernahme erlauben'));
        expect(confirmation.answer, isTrue);
        final client = AccountClientPreview();
        final target = (await accounts.load()).single;
        await tester.pumpWidget(app(RemoteControlPage(key: UniqueKey(), accountDevice: target, accountRepository: accounts, controller: client)));
        await tester.pumpAndSettle();
        expect(client.connected, isTrue); expect(client.receivedKey, secret); expect(client.receivedMode, 'account');
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        client.dispose(); confirmation.dispose(); host.dispose(); await accounts.events.close();
        await tester.binding.setSurfaceSize(null);
      });
    }
  }
}
