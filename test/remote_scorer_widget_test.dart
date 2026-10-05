import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_tournament_manager/app/app_theme.dart';
import 'package:dart_tournament_manager/features/remote_control/application/remote_client_controller.dart';
import 'package:dart_tournament_manager/features/remote_control/application/remote_host_controller.dart';
import 'package:dart_tournament_manager/features/remote_control/application/remote_scorer_host.dart';
import 'package:dart_tournament_manager/features/remote_control/presentation/remote_host_surface.dart';
import 'package:dart_tournament_manager/features/remote_control/presentation/remote_scorer_view.dart';
import 'package:dart_tournament_manager/features/scorer/application/scorer_controller.dart';
import 'package:dart_tournament_manager/features/scorer/presentation/scorer_match_page.dart';
import 'package:dart_tournament_manager/features/scorer/presentation/widgets/score_keypad.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'remote_scorer_test.dart' show remoteTestSettings;

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
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'late acknowledgement after timeout requires explicit reconnection',
    (tester) async {
      final host = RemoteScorerHost();
      final main = ScorerController(remoteTestSettings());
      host.attach(main, 'timeout');
      final client = RemoteClientController();
      client.scorer.receive(host.snapshot());
      Map<String, dynamic>? delayed;
      client.scorer.send = (message) async {
        delayed = message;
      };
      final submitted = client.scorer.command('score', values: {'points': 60});
      await tester.pump(const Duration(seconds: 11));
      expect(await submitted, isFalse);
      client.scorer.receive(await host.execute(delayed!));
      expect(client.scorer.controller!.scores, main.scores);
      expect(client.scorer.ready, isFalse);
      expect(
        await client.scorer.command('score', values: {'points': 60}),
        isFalse,
      );
      client.scorer.beginConnection();
      client.scorer.receive(host.snapshot());
      expect(client.scorer.ready, isTrue);
      client.dispose();
      host.dispose();
      main.dispose();
    },
  );

  testWidgets(
    'ordinary host scorer registers; remote mutation updates existing host page',
    (tester) async {
      final host = RemoteHostController();
      await tester.pumpWidget(
        RemoteHostScope(
          controller: host,
          child: MaterialApp(
            theme: buildDartTournamentTheme(),
            home: ScorerMatchPage(
              settings: remoteTestSettings(),
              onExit: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final state = host.scorer.snapshot();
      expect(state['sessionId'], isNotNull);
      expect(state['actions'], isEmpty);
      final result = await host.scorer.execute({
        'commandId': 'test:1',
        'revision': state['revision'],
        'sessionId': state['sessionId'],
        'action': 'score',
        'points': 60,
      });
      await tester.pumpAndSettle();
      expect(result['error'], isNull);
      expect(find.text('441'), findsOneWidget);
      expect((host.scorer.snapshot()['actions'] as List).single['points'], 60);
      await tester.pumpWidget(const SizedBox());
      expect(host.scorer.snapshot()['sessionId'], isNull);
      host.dispose();
    },
  );

  for (final size in [
    const Size(360, 800),
    const Size(800, 600),
    const Size(1440, 900),
  ]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('native remote scorer $size text $scale', (tester) async {
        await tester.binding.setSurfaceSize(size);
        final main = ScorerController(remoteTestSettings());
        final host = RemoteScorerHost()..attach(main, 'native');
        final client = RemoteClientController();
        client.scorer.receive(host.snapshot());
        client.scorer.send = (message) async =>
            client.scorer.receive(await host.execute(message));
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
              child: Scaffold(body: RemoteScorerView(client: client)),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(Image), findsNothing);
        expect(find.byType(ScoreKeypad), findsOneWidget);
        expect(find.byType(ScorerMatchPage), findsOneWidget);
        expect(tester.takeException(), isNull);
        final pad = tester.widget<ScoreKeypad>(find.byType(ScoreKeypad));
        expect(await pad.onSubmit(60), isTrue);
        await tester.pumpAndSettle();
        expect(main.scores, [441, 501]);
        expect(client.scorer.controller!.scores, main.scores);
        expect(find.text('441'), findsOneWidget);
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
              'build/layout_previews/remote_native_${size.width.toInt()}.png',
            );
            await file.parent.create(recursive: true);
            await file.writeAsBytes(bytes!.buffer.asUint8List());
          });
        }
        host.cameraState(
          available: true,
          open: true,
          pending: true,
          darts: ['T20', 'D19', 'S7'],
        );
        client.scorer.receive(host.snapshot());
        await tester.pumpAndSettle();
        expect(find.text('T20'), findsOneWidget);
        expect(find.text('Aufnahme übernehmen'), findsOneWidget);
        expect(
          tester.widget<ScoreKeypad>(find.byType(ScoreKeypad)).enabled,
          isFalse,
        );
        expect(tester.takeException(), isNull);
        client.scorer.disconnect();
        await tester.pumpAndSettle();
        expect(
          tester.widget<ScoreKeypad>(find.byType(ScoreKeypad)).enabled,
          isFalse,
        );
        await tester.pumpWidget(const SizedBox());
        client.dispose();
        host.dispose();
        main.dispose();
        await tester.binding.setSurfaceSize(null);
      });
    }
  }
}
