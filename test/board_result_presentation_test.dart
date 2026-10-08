import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_tournament_manager/features/devices/application/devices_controller.dart';
import 'package:dart_tournament_manager/features/devices/data/board_display_server.dart';
import 'package:dart_tournament_manager/features/devices/domain/board_display.dart';
import 'package:dart_tournament_manager/features/devices/presentation/board_display_view.dart';
import 'package:dart_tournament_manager/features/devices/presentation/device_match_end_screen.dart';

class ResultReceiver extends BoardDisplayServer {
  @override
  bool get connected => true;
  void assign(BoardDisplay? next) {
    display = next;
    notifyListeners();
  }
}

const first = BoardDisplay(
  tournamentId: 'cup',
  tournamentName: 'Cup',
  board: 1,
  state: 'running',
  matchId: 'first',
  home: 'Anna mit einem langen Spielernamen',
  away: 'Ben',
);
const next = BoardDisplay(
  tournamentId: 'cup',
  tournamentName: 'Cup',
  board: 1,
  state: 'planned',
  matchId: 'second',
  home: 'Clara',
  away: 'David',
);
const last = BoardDisplay(
  tournamentId: 'cup',
  tournamentName: 'Cup',
  board: 1,
  state: 'planned',
  matchId: 'third',
  home: 'Eva',
  away: 'Finn',
);
Map<String, dynamic> result() => {
  'version': 1,
  'matchId': 'first',
  'legs': [3, 1],
  'sets': [0, 0],
  'statistics': {'winner': 0},
};

void main() {
  testWidgets('skip reveals latest assignment immediately', (tester) async {
    final receiver = ResultReceiver()..assign(first);
    final devices = DevicesController(receiver: receiver);
    addTearDown(devices.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: AnimatedBuilder(
          animation: devices,
          builder: (_, _) => BoardDisplayView(controller: devices),
        ),
      ),
    );
    receiver.completeMatch(result());
    receiver.assign(next);
    await tester.pump();
    await tester.scrollUntilVisible(find.text('Überspringen'), 200);
    await tester.tap(find.text('Überspringen'));
    await tester.pump();
    expect(find.text('Clara'), findsOneWidget);
    receiver.assign(first);
    await tester.pump();
    expect(find.text('Warte auf Spielzuweisung …'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  const font = String.fromEnvironment('LAYOUT_PREVIEW_FONT');
  setUpAll(() async {
    if (font.isNotEmpty) {
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
      await (FontLoader(
        'Roboto',
      )..addFont(File(font).readAsBytes().then(ByteData.sublistView))).load();
    }
  });
  testWidgets(
    'result delivery is immediate; latest assignment waits twenty seconds without timer reset',
    (tester) async {
      final receiver = ResultReceiver()..assign(first);
      final devices = DevicesController(receiver: receiver);
      addTearDown(devices.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: AnimatedBuilder(
            animation: devices,
            builder: (_, _) => BoardDisplayView(controller: devices),
          ),
        ),
      );
      receiver.completeMatch(result());
      await tester.pump();
      expect(receiver.completedResult!['matchId'], 'first');
      expect(find.byType(DeviceMatchEndScreen), findsOneWidget);
      receiver.assign(next);
      await tester.pump(const Duration(seconds: 3));
      expect(find.byType(DeviceMatchEndScreen), findsOneWidget);
      receiver.assign(last);
      await tester.pump(const Duration(seconds: 16));
      expect(find.byType(DeviceMatchEndScreen), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(DeviceMatchEndScreen), findsNothing);
      expect(find.text('Eva'), findsOneWidget);
      expect(receiver.completedResult!['matchId'], 'first');
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'release also retains end screen; no assignment keeps result after twenty seconds',
    (tester) async {
      final receiver = ResultReceiver()..assign(first);
      final devices = DevicesController(receiver: receiver);
      addTearDown(devices.dispose);
      receiver.completeMatch(result());
      await tester.pump(const Duration(seconds: 21));
      expect(devices.boardPresentation.result, isNotNull);
      receiver.assign(null);
      expect(devices.boardPresentation.display, isNull);
      receiver.assign(first); // Duplicate polling must not start another hold.
      expect(devices.boardPresentation.result, isNull);
    },
  );

  for (final size in [
    const Size(360, 800),
    const Size(800, 600),
    const Size(1440, 900),
  ]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('waiting start button $size text $scale', (tester) async {
        await tester.binding.setSurfaceSize(size);
        final receiver = ResultReceiver()..assign(next);
        final devices = DevicesController(receiver: receiver);
        addTearDown(devices.dispose);
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: AnimatedBuilder(
              animation: devices,
              builder: (_, _) => BoardDisplayView(controller: devices),
            ),
          ),
        );
        expect(find.text('Partie starten'), findsNothing);
        receiver.assign(
          BoardDisplay.fromJson({...next.toJson(), 'allowDeviceStart': true}),
        );
        await tester.pump();
        await tester.ensureVisible(find.text('Partie starten'));
        await tester.tap(find.text('Partie starten'));
        await tester.pump();
        expect(receiver.startPending, isTrue);
        expect(find.text('Start angefordert …'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pump(const Duration(seconds: 20));
        expect(receiver.startPending, isFalse);
        await tester.pumpWidget(const SizedBox());
        await tester.binding.setSurfaceSize(null);
      });
      testWidgets('result screen $size text $scale', (tester) async {
        await tester.binding.setSurfaceSize(size);
        final preview = GlobalKey();
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: RepaintBoundary(
              key: preview,
              child: DeviceMatchEndScreen(
                display: first,
                result: result(),
                onExit: () {},
                onSkip: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('${first.home} gewinnt!'), findsOneWidget);
        if (font.isNotEmpty && scale == 1 && size.width != 800) {
          await tester.runAsync(() async {
            final boundary =
                preview.currentContext!.findRenderObject()
                    as RenderRepaintBoundary;
            final image = await boundary.toImage();
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            image.dispose();
            final file = File(
              'build/layout_previews/board_end_${size.width.toInt()}.png',
            );
            await file.parent.create(recursive: true);
            await file.writeAsBytes(bytes!.buffer.asUint8List());
          });
        }
        await tester.scrollUntilVisible(find.textContaining('3 Legs'), 200);
        expect(find.textContaining('3 Legs'), findsOneWidget);
        await tester.scrollUntilVisible(find.text('Überspringen'), 200);
        expect(find.text('Überspringen'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.binding.setSurfaceSize(null);
      });
    }
  }
}
