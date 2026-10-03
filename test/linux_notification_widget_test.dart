import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_tournament_manager/app/app_theme.dart';
import 'package:dart_tournament_manager/features/notifications/data/app_push_repository.dart';
import 'package:dart_tournament_manager/features/notifications/data/linux_notification_service.dart';
import 'package:dart_tournament_manager/features/notifications/presentation/linux_push_device_menu.dart';

class _Repository extends AppPushRepository {
  @override
  String? get userId => 'owner';
}

class _Service extends LinuxNotificationService {
  _Service() : super(_Repository());
  bool enabled = false;
  @override
  Future<Map<String, dynamic>?> configuration() async => enabled
      ? {'schemaVersion': 1, 'owner': 'owner', 'name': 'Linux Test'}
      : null;
  @override
  Future<bool> active() async => enabled;
  @override
  Future<void> enable(String name) async {
    enabled = true;
  }

  @override
  Future<void> disable() async {
    enabled = false;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const font = String.fromEnvironment('LAYOUT_PREVIEW_FONT');
  setUpAll(() async {
    if (font.isNotEmpty) {
      await (FontLoader(
        'Roboto',
      )..addFont(File(font).readAsBytes().then(ByteData.sublistView))).load();
    }
  });
  for (final size in [
    const Size(360, 800),
    const Size(800, 600),
    const Size(1440, 900),
  ]) {
    testWidgets('Linux background reception explicit enable/disable at $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final service = _Service();
      final preview = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          theme: buildDartTournamentTheme(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(2)),
            child: child!,
          ),
          home: RepaintBoundary(
            key: preview,
            child: Scaffold(
              body: SingleChildScrollView(
                child: LinuxPushDeviceMenu(service: service),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(service.enabled, isFalse);
      final enable = find.text('Hintergrundempfang aktivieren');
      await tester.ensureVisible(enable);
      await tester.pumpAndSettle();
      await tester.tap(enable);
      await tester.pumpAndSettle();
      expect(service.enabled, isTrue);
      expect(tester.takeException(), isNull);
      final disable = find.text('Deaktivieren');
      await tester.ensureVisible(disable);
      await tester.pumpAndSettle();
      if (font.isNotEmpty) {
        await tester.runAsync(() async {
          final picture =
              await (preview.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary)
                  .toImage();
          final bytes = await picture.toByteData(
            format: ui.ImageByteFormat.png,
          );
          final file = File(
            'build/layout_previews/linux_notifications_${size.width}.png',
          );
          await file.parent.create(recursive: true);
          await file.writeAsBytes(bytes!.buffer.asUint8List());
          picture.dispose();
        });
      }
      await tester.tap(disable);
      await tester.pumpAndSettle();
      expect(service.enabled, isFalse);
      expect(tester.takeException(), isNull);
    });
  }
}
