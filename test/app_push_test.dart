import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:dart_tournament_manager/app/app_theme.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_tournament_manager/features/notifications/data/app_push_repository.dart';
import 'package:dart_tournament_manager/features/notifications/presentation/push_sender_page.dart';
import 'package:dart_tournament_manager/features/notifications/presentation/push_sender_menu.dart';

class FakePushRepository extends AppPushRepository {
  FakePushRepository({this.allowed = true});
  final bool allowed;
  final requests = <String>[];
  @override
  Future<bool> canSend() async => allowed;
  @override
  Future<List<PushDevice>> devices() async => [
    const PushDevice(
      id: 'device',
      name: 'Android Tablet mit einem langen Gerätenamen',
      owner: 'ProfGans Test',
      platform: 'android',
    ),
  ];
  @override
  Future<Map<String, dynamic>> send({
    required String requestId,
    required String title,
    required String body,
    required List<String> deviceIds,
  }) async {
    requests.add(requestId);
    expect(deviceIds, ['device']);
    return {'status': 'complete', 'accepted': 1, 'failed': 0};
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const previewFont = String.fromEnvironment('LAYOUT_PREVIEW_FONT');
  setUpAll(() async {
    if (previewFont.isEmpty) return;
    await (FontLoader('Roboto')..addFont(
          File(previewFont).readAsBytes().then((b) => ByteData.sublistView(b)),
        ))
        .load();
  });
  testWidgets('sender button remains hidden without server permission', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PushSenderMenu(repository: FakePushRepository(allowed: false)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Push-Nachricht senden'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: PushSenderMenu(repository: FakePushRepository())),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Push-Nachricht senden'), findsOneWidget);
  });
  for (final size in [
    const Size(360, 800),
    const Size(800, 600),
    const Size(1440, 900),
  ]) {
    testWidgets(
      'sender validates and reuses request identity at $size with large text',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final repo = FakePushRepository();
        final previewKey = GlobalKey();
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
              key: previewKey,
              child: PushSenderPage(repository: repo),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byType(TextFormField).first,
          'Wichtige Neuigkeiten',
        );
        await tester.enterText(
          find.byType(TextFormField).last,
          'Am Samstag beginnt unser Turnier.',
        );
        await tester.scrollUntilVisible(
          find.byType(CheckboxListTile),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.ensureVisible(find.byType(CheckboxListTile));
        await tester.pumpAndSettle();
        await tester.tap(find.byType(CheckboxListTile));
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.text('Nachricht senden'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.ensureVisible(find.text('Nachricht senden'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Nachricht senden'));
        await tester.pumpAndSettle();
        expect(repo.requests.length, 1);
        if (previewFont.isNotEmpty) {
          await tester.runAsync(() async {
            final boundary =
                previewKey.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            final picture = await boundary.toImage();
            final bytes = await picture.toByteData(
              format: ui.ImageByteFormat.png,
            );
            final file = File('build/layout_previews/push_${size.width}.png');
            await file.parent.create(recursive: true);
            await file.writeAsBytes(bytes!.buffer.asUint8List());
            picture.dispose();
          });
        }
        await tester.ensureVisible(find.text('Senden / Status erneut prüfen'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Senden / Status erneut prüfen'));
        await tester.pumpAndSettle();
        expect(repo.requests[0], repo.requests[1]);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
