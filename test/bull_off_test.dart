import 'dart:math';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_tournament_manager/features/scorer/domain/bull_off.dart';
import 'package:dart_tournament_manager/features/scorer/domain/scorer_settings.dart';
import 'package:dart_tournament_manager/features/scorer/domain/x01/x01_models.dart';
import 'package:dart_tournament_manager/features/scorer/presentation/bull_off_page.dart';
import 'package:dart_tournament_manager/features/scorer/presentation/scorer_setup_page.dart';
import 'package:dart_tournament_manager/features/scorer/domain/scorer_opponents.dart';
import 'package:dart_tournament_manager/features/scorer/data/repositories/checkout_route_repository.dart';
import 'support/scorer_lobby_fake.dart';
import 'support/scorer_setup_navigation.dart';

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
  BullOff game(BullOffRule rule, [int players = 2]) =>
      BullOff(rule: rule, players: players, random: Random(4));

  test('WDF compares distance outside; PDC retries all outside in reverse', () {
    for (final rule in [BullOffRule.wdf, BullOffRule.pdc]) {
      final g = game(rule);
      final order = List.of(g.order);
      g.record(BullOffHit.outside(20));
      g.record(BullOffHit.outside(40));
      g.resolve();
      if (rule == BullOffRule.wdf) {
        expect(g.winner, order.first);
      } else {
        expect(g.winner, isNull);
        expect(g.order, order.reversed.toList());
        expect(g.round, 2);
        expect(g.hits, isEmpty);
      }
    }
  });
  test('Bull beats 25; matching bull zones require a new round', () {
    for (final rule in [BullOffRule.wdf, BullOffRule.pdc]) {
      for (final hit in [
        const BullOffHit.bull(),
        const BullOffHit.outerBull(),
      ]) {
        final g = game(rule);
        g.record(hit);
        g.record(hit);
        g.resolve();
        expect(g.round, 2);
        final winner = g.current;
        g.record(const BullOffHit.bull());
        g.record(const BullOffHit.outerBull());
        g.resolve();
        expect(g.winner, winner);
      }
    }
  });
  test('Only tied leaders repeat; input can be undone before resolving', () {
    final g = game(BullOffRule.wdf, 3);
    final order = List.of(g.order);
    g.record(BullOffHit.outside(40));
    g.record(const BullOffHit.bull());
    g.record(const BullOffHit.outerBull());
    g.undo();
    expect(g.current, order.last);
    g.record(const BullOffHit.bull());
    g.resolve();
    expect(g.order, [order[2], order[1]]);
  });
  test('WDF equal distances tie and invalid distances cannot enter', () {
    final g = game(BullOffRule.wdf);
    g.record(BullOffHit.outside(30));
    g.record(BullOffHit.outside(30));
    g.resolve();
    expect(g.winner, isNull);
    for (final bad in [double.nan, double.infinity, -1.0, 15.9]) {
      expect(() => BullOffHit.outside(bad), throwsArgumentError);
    }
    expect(g.resolve, throwsStateError);
  });

  const players = [ScorerParticipant('Anna'), ScorerParticipant('Ben')];
  testWidgets(
    'Setup cancellation keeps draft; bull winner reaches game settings',
    (tester) async {
      await tester.runAsync(
        () => CheckoutRouteRepository.instance.initialize(),
      );
      ScorerSettings? started;
      await tester.pumpWidget(
        MaterialApp(
          home: ScorerSetupPage(
            opponents: ScorerOpponents.players,
            lobbyRepository: FakeScorerLobbyRepository(),
            remoteStart: (settings) async {
              started = settings;
              return false;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await scorerSetupNext(tester);
      final selector = find.byType(DropdownButtonFormField<BullOffRule>);
      await tester.scrollUntilVisible(
        selector,
        180,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(selector);
      await tester.pumpAndSettle();
      await tester.tap(find.text('WDF').last);
      await tester.pumpAndSettle();
      await scorerSetupNext(tester);
      Future<void> start() async {
        await tester.scrollUntilVisible(
          find.text('Spiel starten'),
          180,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(find.text('Spiel starten'));
        await tester.pumpAndSettle();
      }

      await start();
      expect(find.byType(BullOffPage), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(started, isNull);
      expect(find.text('Ausbullen: WDF'), findsOneWidget);
      await start();
      final first = tester
          .widget<Text>(find.textContaining('wirft auf Bull'))
          .data!;
      final expected = first.startsWith('Spieler 1') ? 0 : 1;
      await tester.scrollUntilVisible(
        find.widgetWithText(FilledButton, 'Bull · 50'),
        180,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Bull · 50'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Outer Bull · 25'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Runde auswerten'),
        180,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Runde auswerten'));
      await tester.pumpAndSettle();
      final finish = find.textContaining('beginnt · Spiel starten');
      await tester.scrollUntilVisible(
        finish,
        180,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(finish);
      await tester.pumpAndSettle();
      expect(started?.startingPlayer, expected);
    },
  );
  for (final size in [
    const Size(360, 800),
    const Size(800, 600),
    const Size(1440, 900),
  ]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('Bull-off layout $size scale $scale', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final key = GlobalKey();
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: RepaintBoundary(
              key: key,
              child: const BullOffPage(rule: BullOffRule.wdf, players: players),
            ),
          ),
        );
        await tester.pumpAndSettle();
        if (font.isNotEmpty && scale == 1) {
          await tester.runAsync(() async {
            final image =
                await (key.currentContext!.findRenderObject()!
                        as RenderRepaintBoundary)
                    .toImage();
            final data = await image.toByteData(format: ui.ImageByteFormat.png);
            final file = File(
              'build/layout_previews/bull_off_${size.width.toInt()}.png',
            );
            await file.parent.create(recursive: true);
            await file.writeAsBytes(data!.buffer.asUint8List());
            image.dispose();
          });
        }
        await tester.scrollUntilVisible(
          find.text('Abstand übernehmen'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  }
  testWidgets('PDC winner chooses starter and returns index', (tester) async {
    int? starter;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              starter = await Navigator.of(context).push<int>(
                MaterialPageRoute(
                  builder: (_) => const BullOffPage(
                    rule: BullOffRule.pdc,
                    players: players,
                  ),
                ),
              );
            },
            child: const Text('Öffnen'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Öffnen'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bull · 50'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Außerhalb'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Runde auswerten'),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Runde auswerten'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Ben beginnt'),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Ben beginnt'));
    await tester.pumpAndSettle();
    expect(starter, 1);
  });
  testWidgets('Bots throw automatically; leaving cancels pending throws', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: BullOffPage(
          rule: BullOffRule.pdc,
          players: [
            ScorerParticipant(
              'Bot A',
              bot: BotProfile(skill: 60, finishingSkill: 60),
            ),
            ScorerParticipant(
              'Bot B',
              bot: BotProfile(skill: 60, finishingSkill: 60),
            ),
          ],
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Runde auswerten'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));
    expect(tester.takeException(), isNull);
  });
}
