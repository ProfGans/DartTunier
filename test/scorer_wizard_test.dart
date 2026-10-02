import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_tournament_manager/features/scorer/presentation/scorer_page.dart';
import 'package:dart_tournament_manager/features/scorer/presentation/scorer_setup_page.dart';
import 'package:dart_tournament_manager/features/scorer/presentation/scorer_match_page.dart';
import 'package:dart_tournament_manager/features/scorer/presentation/lobby/scorer_join_page.dart';
import 'package:dart_tournament_manager/features/scorer/presentation/lobby/scorer_invitation_listener.dart';
import 'package:dart_tournament_manager/features/scorer/presentation/lobby/scorer_lobby_panel.dart';
import 'package:dart_tournament_manager/features/scorer/data/bot_settings_storage.dart';
import 'package:dart_tournament_manager/features/scorer/data/repositories/checkout_route_repository.dart';
import 'package:dart_tournament_manager/features/scorer/domain/bot_settings.dart';
import 'package:dart_tournament_manager/features/scorer/domain/scorer_opponents.dart';
import 'package:dart_tournament_manager/features/scorer/domain/scorer_lobby.dart';
import 'support/scorer_lobby_fake.dart';

class _Storage extends BotSettingsStorage {
  @override
  Future<BotSettings> load() async => const BotSettings(useTheoAverage: false);
}

Future<void> reveal(WidgetTester tester, String text) async {
  await tester.scrollUntilVisible(
    find.text(text),
    250,
    scrollable: find
        .descendant(
          of: find.byType(ListView).first,
          matching: find.byType(Scrollable),
        )
        .first,
    maxScrolls: 80,
  );
  await tester.pumpAndSettle();
}

void main() {
  for (final mode in ScorerOpponents.values) {
    testWidgets('Wizard ${mode.name} starts with only relevant opponents', (
      tester,
    ) async {
      await tester.runAsync(
        () => CheckoutRouteRepository.instance.initialize(),
      );
      await tester.pumpWidget(
        MaterialApp(home: ScorerPage(botStorage: _Storage())),
      );
      expect(find.byType(TextFormField), findsNothing);
      final label = switch (mode) {
        ScorerOpponents.players => 'Gegen Spieler spielen',
        ScorerOpponents.bots => 'Gegen Bot spielen',
        ScorerOpponents.mixed => 'Gemischtes Spiel',
      };
      await reveal(tester, label);
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      expect(find.byType(Slider), findsNothing);
      expect(find.byTooltip('Bot-Einstellungen'), findsNothing);
      final add = mode == ScorerOpponents.players
          ? 'Spieler hinzufügen'
          : 'Bot hinzufügen';
      await reveal(tester, add);
      expect(
        find.text(
          mode == ScorerOpponents.players
              ? 'Bot hinzufügen'
              : mode == ScorerOpponents.bots
              ? 'Spieler hinzufügen'
              : 'Spieler hinzufügen',
        ),
        mode == ScorerOpponents.mixed ? findsOneWidget : findsNothing,
      );
      await tester.tap(find.text(add));
      await tester.pumpAndSettle();
      await reveal(tester, 'Spiel starten');
      await tester.tap(find.text('Spiel starten'));
      await tester.pumpAndSettle();
      final settings = tester
          .widget<ScorerMatchPage>(find.byType(ScorerMatchPage))
          .settings;
      expect(
        settings.participants.length,
        mode == ScorerOpponents.mixed ? 4 : 3,
      );
      expect(
        mode.accepts(
          settings.participants.where((p) => p.bot == null).length,
          settings.participants.where((p) => p.bot != null).length,
        ),
        true,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'Account joins appear once and group invitations do not add unconfirmed accounts',
    (tester) async {
      final repo = FakeScorerLobbyRepository();
      await tester.pumpWidget(
        MaterialApp(
          home: ScorerSetupPage(
            opponents: ScorerOpponents.players,
            lobbyRepository: repo,
          ),
        ),
      );
      await reveal(tester, 'QR-Code & Einladungen öffnen');
      await tester.tap(find.text('QR-Code & Einladungen öffnen'));
      await tester.pumpAndSettle();
      await reveal(tester, 'Aus Gruppen einladen');
      await tester.tap(find.text('Aus Gruppen einladen'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Einladen'));
      await tester.pumpAndSettle();
      expect(repo.invited, 'guest');
      await tester.tap(find.text('Schließen'));
      await tester.pumpAndSettle();
      repo.members = [const LobbyMember('guest', 'Anna Beispiel')];
      final controller = tester
          .widget<ScorerLobbyPanel>(find.byType(ScorerLobbyPanel))
          .controller;
      await controller.refresh();
      await tester.pumpAndSettle();
      await controller.refresh();
      await tester.pumpAndSettle();
      await reveal(tester, 'Mit Konto angemeldet');
      expect(find.text('Anna Beispiel'), findsOneWidget);
      expect(find.text('Mit Konto angemeldet'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('Join validates code before submitting and shows success', (
    tester,
  ) async {
    final repo = FakeScorerLobbyRepository();
    await tester.pumpWidget(
      MaterialApp(home: ScorerJoinPage(repository: repo)),
    );
    await tester.tap(find.text('Mit meinem Konto beitreten'));
    await tester.pumpAndSettle();
    expect(repo.joins, 0);
    await tester.enterText(
      find.byType(TextField),
      '0123456789ABCDEF0123456789ABCDEF',
    );
    await tester.tap(find.text('Mit meinem Konto beitreten'));
    await tester.pumpAndSettle();
    expect(repo.joins, 1);
    expect(find.text('Du bist dabei!'), findsOneWidget);
  });

  testWidgets(
    'Incoming community invitation appears as popup and accepts explicitly',
    (tester) async {
      final repo = FakeScorerLobbyRepository()
        ..pending = [const ScorerInvitation('invite', 'Ben')];
      final key = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        ScorerInvitationListener(
          navigatorKey: key,
          repository: repo,
          links: const Stream.empty(),
          child: MaterialApp(
            navigatorKey: key,
            home: const Scaffold(body: Text('Start')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Einladung zum Scorer'), findsOneWidget);
      expect(repo.accepted, isNull);
      await tester.tap(find.text('Mitspielen'));
      await tester.pumpAndSettle();
      expect(repo.accepted, true);
      expect(find.text('Einladung zum Scorer'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );

  for (final size in [
    const Size(360, 800),
    const Size(800, 600),
    const Size(1440, 900),
  ]) {
    testWidgets(
      'Wizard and mixed setup preserve input across resize at $size and 200% text',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = size;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(2)),
              child: child!,
            ),
            home: ScorerPage(botStorage: _Storage()),
          ),
        );
        await reveal(tester, 'Gemischtes Spiel');
        await tester.tap(find.text('Gemischtes Spiel'));
        await tester.pumpAndSettle();
        await reveal(tester, 'Startpunkte');
        final field = find.widgetWithText(TextFormField, 'Startpunkte');
        await tester.ensureVisible(field);
        await tester.enterText(field, '301');
        tester.view.physicalSize = Size(size.height, size.width);
        await tester.pumpAndSettle();
        expect(find.text('301'), findsOneWidget);
        await reveal(tester, 'Spiel starten');
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
