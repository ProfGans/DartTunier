import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dart_tournament_manager/features/scorer/data/scorer_monitor_preferences.dart';
import 'package:dart_tournament_manager/features/scorer/presentation/scorer_match_page.dart';
import 'package:dart_tournament_manager/features/scorer/presentation/monitor/scorer_monitor_preference_tile.dart';
import 'package:dart_tournament_manager/features/scorer/application/scorer_controller.dart';
import 'package:dart_tournament_manager/features/scorer/application/scorer_monitor_window.dart';
import 'package:dart_tournament_manager/features/scorer/domain/scorer_settings.dart';
import 'package:dart_tournament_manager/features/scorer/domain/x01/x01_rules.dart';
import 'package:dart_tournament_manager/features/scorer/presentation/monitor/scorer_monitor_page.dart';

class _RealHttp extends HttpOverrides {}

void main() {
  testWidgets('Monitor is reachable from match and automatically opens once', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      ScorerMonitorPreferences.key: 'inApp',
    });
    await tester.pumpWidget(
      MaterialApp(
        home: ScorerMatchPage(
          settings: ScorerSettings(
            participants: const [
              ScorerParticipant('A'),
              ScorerParticipant('B'),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(ScorerMonitorPage), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(ScorerMonitorPage), findsNothing);
    await tester.tap(find.widgetWithText(OutlinedButton, 'Monitor-Modus'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nur Punkte in der App anzeigen'));
    await tester.pumpAndSettle();
    expect(find.byType(ScorerMonitorPage), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Monitor preference persists with large text on mobile', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: const Scaffold(
            body: SingleChildScrollView(child: ScorerMonitorPreferenceTile()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Punkteanzeige in der App'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Punkteanzeige in der App'));
    await tester.pumpAndSettle();
    expect(await ScorerMonitorPreferences().load(), ScorerMonitorStart.inApp);
    expect(tester.takeException(), isNull);
  });
  ScorerController scorer() => ScorerController(
    ScorerSettings(
      participants: const [
        ScorerParticipant('Langer Spielername mit mehreren Bestandteilen'),
        ScorerParticipant('Zweiter Spieler'),
        ScorerParticipant('Dritter Spieler'),
      ],
    ),
  );

  test(
    'Monitor serves live points read-only and closes with its owner',
    () async {
      final c = scorer();
      final monitor = ScorerMonitorWindow();
      final client = HttpOverrides.runWithHttpOverrides(
        () => HttpClient(),
        _RealHttp(),
      );
      addTearDown(() async {
        client.close(force: true);
        await monitor.close();
        c.dispose();
      });
      final uri = await monitor.start(c);
      Future<HttpClientResponse> get(Uri url) async =>
          (await client.getUrl(url)).close();
      final html = await (await get(uri)).transform(utf8.decoder).join();
      expect(html, contains('textContent=p.name'));
      c.throwDart(const X01Rules().createTriple(20));
      final state = jsonDecode(
        await (await get(uri.resolve('state'))).transform(utf8.decoder).join(),
      );
      expect(state['players'][0]['score'], 441);
      expect(state['players'][0]['active'], true);
    expect(state['players'][0]['legs'], 0);
    expect(state['players'][0]['sets'], 0);
    expect(state['format'], contains('Best of 3 Legs'));
      expect((await get(uri.resolve('/state'))).statusCode, 404);
      final post = await client.postUrl(uri.resolve('state'));
      expect((await post.close()).statusCode, 404);
      await monitor.close();
      await expectLater(monitor.start(c), throwsStateError);
    },
  );

  for (final size in [
    const Size(360, 800),
    const Size(800, 600),
    const Size(1440, 900),
  ]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('Monitor live and responsive $size at $scale', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final c = scorer();
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: ScorerMonitorPage(controller: c),
          ),
        );
        c.throwDart(const X01Rules().createTriple(20));
        await tester.pump();
        expect(find.text('441'), findsOneWidget);
        c.undo();
        await tester.pump();
        expect(find.text('441'), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        c.dispose();
      });
    }
  }
}
