import 'package:dart_tournament_manager/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('creates a knockout-only tournament', (tester) async {
    await tester.pumpWidget(const DartTournamentApp());

    await tester.tap(find.text('Turnier erstellen'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'Anzahl'), '4');
    await tester.tap(find.text('Spieler erzeugen'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('stage-type-field')),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Gruppenphase'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('K.-o.-Runde').last);
    await tester.pumpAndSettle();

    expect(find.text('Start mit allen Spielern'), findsOneWidget);
    expect(find.text('4 Weiter'), findsOneWidget);
    expect(find.text('4er Feld'), findsOneWidget);
    expect(find.text('Bracket-Vorschau'), findsOneWidget);
    expect(find.text('Zufall'), findsOneWidget);
    expect(find.text('Cross seeded'), findsNothing);

    await tester.scrollUntilVisible(
      find.byTooltip('Etappe hinzufuegen'),
      -400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Etappe hinzufuegen'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('1 Etappen im Turnier'),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('1 Etappen im Turnier'), findsOneWidget);

    await tester.tap(find.byTooltip('Etappe bearbeiten'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('stage-name-field'), skipOffstage: false),
      -400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('stage-name-field'), skipOffstage: false),
      'KO pur',
    );
    await tester.ensureVisible(
      find.byTooltip('Etappe speichern', skipOffstage: false),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Etappe speichern'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('KO pur'),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('KO pur'), findsOneWidget);

    await tester.ensureVisible(find.text('Turnier anlegen'));
    await tester.pumpAndSettle();
    await tester.dragUntilVisible(
      find.text('Turnier anlegen'),
      find.byType(Scrollable).first,
      const Offset(0, -120),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Turnier anlegen'));
    await tester.pumpAndSettle();

    expect(find.text('Turnierbaum'), findsOneWidget);
    expect(find.text('Finale'), findsOneWidget);
    expect(find.text('Positionen bearbeiten'), findsOneWidget);

    await tester.tap(find.text('Positionen bearbeiten'));
    await tester.pumpAndSettle();

    expect(
      find.text('Ziehe Spieler in Runde 1 auf einen anderen Platz oder ein Freilos.'),
      findsOneWidget,
    );
  });

  testWidgets('offers double and triple knockout formats', (tester) async {
    await tester.pumpWidget(const DartTournamentApp());

    await tester.tap(find.text('Turnier erstellen'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'Anzahl'), '6');
    await tester.tap(find.text('Spieler erzeugen'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('stage-type-field')),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Gruppenphase'));
    await tester.pumpAndSettle();
    expect(find.text('Doppel-KO'), findsWidgets);
    expect(find.text('Triple-KO'), findsWidgets);
    await tester.tap(find.text('Doppel-KO').last);
    await tester.pumpAndSettle();

    expect(find.text('Zufall'), findsOneWidget);
    expect(find.text('Cross seeded'), findsNothing);
    expect(find.text('Winners Runde 1'), findsOneWidget);
    expect(find.textContaining('Losers Runde 1'), findsWidgets);
    expect(find.text('Grand Final'), findsWidgets);

    await tester.tap(find.byKey(const ValueKey('stage-type-field')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Triple-KO').last);
    await tester.pumpAndSettle();

    expect(find.text('Zufall'), findsOneWidget);
    expect(find.text('Cross seeded'), findsNothing);
    expect(find.textContaining('automatisch gesetzt'), findsWidgets);
    expect(find.text('0 Niederlagen Runde 1'), findsOneWidget);
    expect(find.text('1 Niederlage Runde 1'), findsOneWidget);
    expect(find.text('2 Niederlagen Runde 1'), findsOneWidget);
    expect(find.text('Triple-KO Finalrunde'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('stage-type-field')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gruppenphase').last);
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('group-play-type-field')),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Jeder gegen jeden').last);
    await tester.pumpAndSettle();
    expect(find.text('Doppel-KO in der Gruppe'), findsWidgets);
    expect(find.text('Triple-KO in der Gruppe'), findsWidgets);
    await tester.tap(find.text('Triple-KO in der Gruppe').last);
    await tester.pumpAndSettle();
  });

  testWidgets('double knockout run starts with round one title', (tester) async {
    final players = List.generate(
      8,
      (index) => TournamentPlayer.generated(index + 1),
    );
    final tournament = CreatedTournament(
      name: 'Doppel-KO Test',
      players: players,
      stages: const [
        TournamentStage(
          name: 'Doppel-K.-o.',
          type: 'double_knockout',
          knockoutParticipantCount: 8,
          knockoutBracketSize: 8,
        ),
      ],
      runStages: [
        KnockoutTournamentRunStage(
          name: 'Doppel-K.-o.',
          eliminationLossLimit: 2,
          rounds: [
            [
              GroupMatch(
                homePlayer: players[0],
                awayPlayer: players[7],
                round: 1,
                label: 'Winners Runde 1',
              ),
              GroupMatch(
                homePlayer: players[1],
                awayPlayer: players[6],
                round: 1,
                label: 'Winners Runde 1',
              ),
            ],
            [
              GroupMatch(round: 2, label: 'Winners Runde 2'),
              GroupMatch(round: 2, label: 'Losers Runde 1'),
            ],
          ],
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(home: TournamentRunPage(tournament: tournament)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Eliminationsplan - Aus nach 2 Niederlagen'), findsOneWidget);
    expect(find.text('Winners Runde 1'), findsOneWidget);
    expect(find.text('Winners Bracket'), findsOneWidget);
    expect(find.text('Losers Bracket'), findsOneWidget);
    expect(find.text('Finale'), findsOneWidget);
    expect(find.textContaining('Gewinner Spiel'), findsWidgets);
    expect(find.text('Freilos'), findsWidgets);
    expect(find.textContaining('Gewinner Losers'), findsNothing);
  });

  testWidgets('double knockout with many byes accepts first results', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final players = List.generate(
      10,
      (index) => TournamentPlayer.generated(index + 1),
    );
    final tournament = CreatedTournament(
      name: 'Doppel-KO Freilose',
      players: players,
      stages: const [
        TournamentStage(
          name: 'Doppel-K.-o.',
          type: 'double_knockout',
          knockoutParticipantCount: 10,
          knockoutBracketSize: 16,
        ),
      ],
      runStages: [
        KnockoutTournamentRunStage(
          name: 'Doppel-K.-o.',
          eliminationLossLimit: 2,
          rounds: [
            [
              for (var index = 0; index < 6; index++)
                GroupMatch(
                  homePlayer: players[index],
                  round: 1,
                  allowsBye: true,
                  label: 'Automatisch gesetzt',
                ),
              GroupMatch(
                homePlayer: players[6],
                awayPlayer: players[9],
                round: 1,
                allowsBye: true,
                label: 'Winners Runde 1',
              ),
              GroupMatch(
                homePlayer: players[7],
                awayPlayer: players[8],
                round: 1,
                allowsBye: true,
                label: 'Winners Runde 1',
              ),
            ],
            [
              for (var index = 0; index < 4; index++)
                GroupMatch(round: 2, label: 'Winners Runde 2'),
              for (var index = 0; index < 4; index++)
                GroupMatch(
                  round: 2,
                  label: 'Losers Runde 1',
                  homePlayer: index == 0 ? players[6] : null,
                  awayPlayer: index == 0 ? players[6] : null,
                  homeLegs: index == 0 ? 2 : null,
                  awayLegs: index == 0 ? 1 : null,
                ),
            ],
            [
              for (var index = 0; index < 4; index++)
                GroupMatch(round: 3, label: 'Losers Runde 2'),
            ],
            [
              for (var index = 0; index < 2; index++)
                GroupMatch(round: 4, label: 'Winners Runde 3'),
            ],
            [
              for (var index = 0; index < 2; index++)
                GroupMatch(round: 5, label: 'Losers Runde 3'),
            ],
            [GroupMatch(round: 6, label: 'Losers Runde 4')],
            [GroupMatch(round: 7, label: 'Winners Runde 4')],
            [GroupMatch(round: 8, label: 'Losers Runde 5')],
            [GroupMatch(round: 9, label: 'Grand Final')],
          ],
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(home: TournamentRunPage(tournament: tournament)),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byTooltip('Ergebnis').first);
    await tester.tap(find.byTooltip('Ergebnis').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('home-legs-field')), '2');
    await tester.enterText(find.byKey(const ValueKey('away-legs-field')), '0');
    await tester.tap(find.text('Speichern'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byTooltip('Ergebnis').at(1));
    await tester.tap(find.byTooltip('Ergebnis').at(1));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('home-legs-field')), '2');
    await tester.enterText(find.byKey(const ValueKey('away-legs-field')), '0');
    await tester.tap(find.text('Speichern'));
    await tester.pumpAndSettle();

    expect(find.text('2'), findsWidgets);
    expect(find.text('Spiel 7'), findsWidgets);
    expect(find.text('Spieler 8'), findsWidgets);
    expect(find.text('Spieler 9'), findsWidgets);
    expect(find.text('Spieler 10'), findsWidgets);
    expect(find.text('Gewinner Spiel 1'), findsNothing);

    final runStage = tournament.runStages.first as KnockoutTournamentRunStage;
    final firstLosersMatch = runStage.rounds
        .expand((round) => round)
        .firstWhere((match) => match.label == 'Losers Runde 1');
    expect(firstLosersMatch.homePlayer, players[9]);
    expect(firstLosersMatch.awayPlayer, isNull);
    expect(firstLosersMatch.homeLegs, isNull);
    expect(firstLosersMatch.awayLegs, isNull);
    final secondLosersMatch = runStage.rounds
        .expand((round) => round)
        .where((match) => match.label == 'Losers Runde 1')
        .elementAt(1);
    expect(secondLosersMatch.homePlayer, players[8]);
    expect(secondLosersMatch.awayPlayer, isNull);
  });

  testWidgets('repairs old malformed double knockout losers bracket', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final players = List.generate(
      10,
      (index) => TournamentPlayer.generated(index + 1),
    );
    final tournament = CreatedTournament(
      name: 'Altes Doppel-KO',
      players: players,
      stages: const [
        TournamentStage(
          name: 'Doppel-K.-o.',
          type: 'double_knockout',
          knockoutParticipantCount: 10,
          knockoutBracketSize: 16,
        ),
      ],
      runStages: [
        KnockoutTournamentRunStage(
          name: 'Doppel-K.-o.',
          eliminationLossLimit: 2,
          rounds: [
            [
              for (var index = 0; index < 6; index++)
                GroupMatch(
                  homePlayer: players[index],
                  round: 1,
                  allowsBye: true,
                  label: 'Automatisch gesetzt',
                ),
              GroupMatch(
                homePlayer: players[6],
                awayPlayer: players[9],
                round: 1,
                allowsBye: true,
                label: 'Winners Runde 1',
              ),
              GroupMatch(
                homePlayer: players[7],
                awayPlayer: players[8],
                round: 1,
                allowsBye: true,
                label: 'Winners Runde 1',
              ),
            ],
            [
              for (var index = 0; index < 4; index++)
                GroupMatch(round: 2, label: 'Winners Runde 2'),
              GroupMatch(round: 2, label: 'Losers Runde 1'),
              GroupMatch(round: 2, label: 'Losers Runde 2'),
              GroupMatch(round: 2, label: 'Losers Runde 3'),
              GroupMatch(round: 2, label: 'Losers Runde 4'),
            ],
            [GroupMatch(round: 3, label: 'Losers Runde 5')],
            [GroupMatch(round: 4, label: 'Losers Runde 6')],
            [GroupMatch(round: 5, label: 'Losers Runde 7')],
            [GroupMatch(round: 6, label: 'Losers Runde 8')],
            [GroupMatch(round: 7, label: 'Losers Runde 9')],
            [GroupMatch(round: 8, label: 'Grand Final')],
          ],
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(home: TournamentRunPage(tournament: tournament)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Losers Runde 9'), findsNothing);
    expect(find.text('Losers Runde 6'), findsOneWidget);

    await tester.ensureVisible(find.byTooltip('Ergebnis').first);
    await tester.tap(find.byTooltip('Ergebnis').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('home-legs-field')), '2');
    await tester.enterText(find.byKey(const ValueKey('away-legs-field')), '0');
    await tester.tap(find.text('Speichern'));
    await tester.pumpAndSettle();

    expect(find.text('2'), findsWidgets);
  });

  testWidgets('triple knockout run shows separate loss brackets', (tester) async {
    final players = List.generate(
      4,
      (index) => TournamentPlayer.generated(index + 1),
    );
    final tournament = CreatedTournament(
      name: 'Triple-KO Test',
      players: players,
      stages: const [
        TournamentStage(
          name: 'Triple-K.-o.',
          type: 'triple_knockout',
          knockoutParticipantCount: 4,
          knockoutBracketSize: 4,
        ),
      ],
      runStages: [
        KnockoutTournamentRunStage(
          name: 'Triple-K.-o.',
          eliminationLossLimit: 3,
          rounds: [
            [
              GroupMatch(
                homePlayer: players[0],
                awayPlayer: players[3],
                round: 1,
                label: '0 Niederlagen Runde 1',
              ),
              GroupMatch(
                homePlayer: players[1],
                awayPlayer: players[2],
                round: 1,
                label: '0 Niederlagen Runde 1',
              ),
            ],
            [
              GroupMatch(round: 2, label: '1 Niederlage Runde 1'),
            ],
            [
              GroupMatch(round: 3, label: '2 Niederlagen Runde 1'),
            ],
          ],
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(home: TournamentRunPage(tournament: tournament)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Winners Bracket'), findsOneWidget);
    expect(find.text('1 Niederlage Bracket'), findsOneWidget);
    expect(find.text('2 Niederlagen Bracket'), findsOneWidget);
    expect(find.text('0 Niederlagen Runde 1'), findsOneWidget);
  });

  testWidgets('triple knockout with many byes accepts first results', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final players = List.generate(
      10,
      (index) => TournamentPlayer.generated(index + 1),
    );
    final tournament = CreatedTournament(
      name: 'Triple-KO Freilose',
      players: players,
      stages: const [
        TournamentStage(
          name: 'Triple-K.-o.',
          type: 'triple_knockout',
          knockoutParticipantCount: 10,
          knockoutBracketSize: 16,
        ),
      ],
      runStages: [
        KnockoutTournamentRunStage(
          name: 'Triple-K.-o.',
          eliminationLossLimit: 3,
          rounds: [
            [
              for (var index = 0; index < 6; index++)
                GroupMatch(
                  homePlayer: players[index],
                  round: 1,
                  allowsBye: true,
                  label: 'Automatisch gesetzt',
                ),
              GroupMatch(
                homePlayer: players[6],
                awayPlayer: players[9],
                round: 1,
                allowsBye: true,
                label: '0 Niederlagen Runde 1',
              ),
              GroupMatch(
                homePlayer: players[7],
                awayPlayer: players[8],
                round: 1,
                allowsBye: true,
                label: '0 Niederlagen Runde 1',
              ),
            ],
          ],
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(home: TournamentRunPage(tournament: tournament)),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byTooltip('Ergebnis').first);
    await tester.tap(find.byTooltip('Ergebnis').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('home-legs-field')), '2');
    await tester.enterText(find.byKey(const ValueKey('away-legs-field')), '0');
    await tester.tap(find.text('Speichern'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byTooltip('Ergebnis').at(1));
    await tester.tap(find.byTooltip('Ergebnis').at(1));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('home-legs-field')), '2');
    await tester.enterText(find.byKey(const ValueKey('away-legs-field')), '1');
    await tester.tap(find.text('Speichern'));
    await tester.pumpAndSettle();

    expect(find.text('2'), findsWidgets);
    expect(find.text('Winners Bracket'), findsOneWidget);
    expect(find.text('Spieler 8'), findsWidgets);
    expect(find.text('Spieler 7'), findsWidgets);
  });

  testWidgets('sets round robin repeats per group', (tester) async {
    await tester.pumpWidget(const DartTournamentApp());

    await tester.tap(find.text('Turnier erstellen'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'Anzahl'), '4');
    await tester.tap(find.text('Spieler erzeugen'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('group-count-field')),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('group-count-field')),
      '2',
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.byKey(
        const ValueKey('round-robin-repeat-plus-2'),
        skipOffstage: false,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('round-robin-repeat-plus-2')));
    await tester.pumpAndSettle();

    expect(find.text('Begegnungen pro Paar'), findsOneWidget);
    expect(find.text('2x'), findsOneWidget);
    expect(find.text('3 Spiele in dieser Etappe'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.byTooltip('Etappe hinzufuegen'),
      -400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Etappe hinzufuegen'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('1 Etappen im Turnier'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('1 Etappen im Turnier'), findsOneWidget);
    expect(
      find.textContaining('Begegnungen: Gruppe A 1x, Gruppe B 2x'),
      findsOneWidget,
    );
  });

  testWidgets('creates mini knockout groups', (tester) async {
    await tester.pumpWidget(const DartTournamentApp());

    await tester.tap(find.text('Turnier erstellen'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'Anzahl'), '4');
    await tester.tap(find.text('Spieler erzeugen'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('group-play-type-field')),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('group-play-type-field')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mini-KO in der Gruppe').last);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('group-count-field')),
      '2',
    );
    await tester.pumpAndSettle();

    expect(find.text('Begegnungen pro Paar'), findsNothing);
    expect(
      find.text('2 Spiele in dieser Etappe', skipOffstage: false),
      findsOneWidget,
    );

    await tester.scrollUntilVisible(
      find.byTooltip('Etappe hinzufuegen'),
      -400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Etappe hinzufuegen'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('1 Etappen im Turnier'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Mini-KO in der Gruppe'), findsOneWidget);

    await tester.dragUntilVisible(
      find.text('Turnier anlegen'),
      find.byType(Scrollable).first,
      const Offset(0, -120),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Turnier anlegen'));
    await tester.pumpAndSettle();

    expect(find.text('Mini-KO-Runde'), findsWidgets);
    expect(find.text('Gruppe A'), findsWidgets);
    expect(find.text('Gruppe B'), findsWidgets);
    expect(find.text('Finale'), findsWidgets);
  });

  testWidgets('sets play type for a single group', (tester) async {
    await tester.pumpWidget(const DartTournamentApp());

    await tester.tap(find.text('Turnier erstellen'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'Anzahl'), '6');
    await tester.tap(find.text('Spieler erzeugen'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('group-count-field')),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('group-count-field')),
      '2',
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.byKey(
        const ValueKey('group-play-type-2-round_robin'),
        skipOffstage: false,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('group-play-type-2-round_robin')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mini-KO').last);
    await tester.pumpAndSettle();

    expect(find.text('5 Spiele in dieser Etappe'), findsOneWidget);
    expect(
      find.byKey(
        const ValueKey('round-robin-repeat-plus-2'),
        skipOffstage: false,
      ),
      findsNothing,
    );

    await tester.scrollUntilVisible(
      find.byTooltip('Etappe hinzufuegen'),
      -400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Etappe hinzufuegen'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('1 Etappen im Turnier'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining(
        'Spieltypen: Gruppe A Jeder gegen jeden, '
        'Gruppe B Mini-KO in der Gruppe',
      ),
      findsOneWidget,
    );
  });

  testWidgets('cross seed gives byes to top group winners', (tester) async {
    await tester.pumpWidget(const DartTournamentApp());

    await tester.tap(find.text('Turnier erstellen'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'Anzahl'), '24');
    await tester.tap(find.text('Spieler erzeugen'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('group-count-field')),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('group-count-field')),
      '6',
    );
    await tester.enterText(
      find.byKey(const ValueKey('group-qualifier-count-field')),
      '12',
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byTooltip('Etappe hinzufuegen'),
      -400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Etappe hinzufuegen'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('stage-type-field')),
      -400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gruppenphase'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('K.-o.-Runde').last);
    await tester.pumpAndSettle();

    expect(find.text('12 Weiter'), findsOneWidget);
    expect(find.text('16er Feld'), findsOneWidget);
    expect(find.text('4 Freilose'), findsOneWidget);
    expect(
      find.text(
        'Cross Seed vergibt Freilose automatisch an die bestplatzierten Teilnehmer.',
      ),
      findsOneWidget,
    );

    for (final label in [
      '1. Gruppe A',
      '1. Gruppe B',
      '1. Gruppe C',
      '1. Gruppe D',
    ]) {
      final labelFinder = find.text(label);
      expect(labelFinder, findsOneWidget);
      final labelTopLeft = tester.getTopLeft(labelFinder);
      final byeFinder = find.text('Freilos').evaluate().where((element) {
        final box = element.renderObject! as RenderBox;
        final topLeft = box.localToGlobal(Offset.zero);
        return (topLeft.dy - labelTopLeft.dy).abs() < 42;
      });
      expect(byeFinder.length, 1);
    }
  });

  testWidgets('cross seed pairs high group places against lower places', (
    tester,
  ) async {
    await tester.pumpWidget(const DartTournamentApp());

    await tester.tap(find.text('Turnier erstellen'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'Anzahl'), '23');
    await tester.tap(find.text('Spieler erzeugen'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('group-count-field')),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('group-count-field')),
      '7',
    );
    await tester.enterText(
      find.byKey(const ValueKey('group-qualifier-count-field')),
      '16',
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byTooltip('Etappe hinzufuegen'),
      -400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Etappe hinzufuegen'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('stage-type-field')),
      -400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gruppenphase'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('K.-o.-Runde').last);
    await tester.pumpAndSettle();

    void expectSamePreviewMatch(String firstLabel, String secondLabel) {
      final firstFinder = find.text(firstLabel);
      final secondFinder = find.text(secondLabel);
      expect(firstFinder, findsOneWidget);
      expect(secondFinder, findsOneWidget);
      final firstTopLeft = tester.getTopLeft(firstFinder);
      final secondTopLeft = tester.getTopLeft(secondFinder);
      expect((firstTopLeft.dy - secondTopLeft.dy).abs() < 42, isTrue);
    }

    expect(find.text('16 Weiter'), findsOneWidget);
    expectSamePreviewMatch('1. Gruppe A', '3. Gruppe B');
    expectSamePreviewMatch('1. Gruppe B', '3. Gruppe A');
    expectSamePreviewMatch('1. Gruppe C', '2. Gruppe G');
    expectSamePreviewMatch('1. Gruppe D', '2. Gruppe F');
    expectSamePreviewMatch('1. Gruppe E', '2. Gruppe D');
    expectSamePreviewMatch('1. Gruppe F', '2. Gruppe E');
    expectSamePreviewMatch('1. Gruppe G', '2. Gruppe C');
  });

  testWidgets('opens tournament creation and manages players', (tester) async {
    await tester.pumpWidget(const DartTournamentApp());

    expect(find.text('Dart Turnierverwaltung'), findsWidgets);
    expect(find.text('Turnier erstellen'), findsOneWidget);

    await tester.tap(find.text('Turnier erstellen'));
    await tester.pumpAndSettle();

    expect(find.text('Neues Turnier'), findsOneWidget);
    expect(find.text('Turniername'), findsOneWidget);
    expect(find.text('Turnierformat'), findsNothing);
    expect(find.text('Gruppenphase'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, 'Anzahl'), '4');
    await tester.tap(find.text('Spieler erzeugen'));
    await tester.pumpAndSettle();

    expect(find.text('4 Spieler im Turnier'), findsOneWidget);
    expect(find.text('Spieler 1'), findsOneWidget);
    expect(find.text('Spieler 4'), findsOneWidget);

    await tester.tap(find.text('Spieler 1'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(TextField, 'Spielername'),
      ),
      'Anna',
    );
    await tester.tap(find.text('Speichern'));
    await tester.pumpAndSettle();

    expect(find.text('Anna'), findsOneWidget);
    expect(find.text('Spieler 1'), findsNothing);

    await tester.enterText(
      find.widgetWithText(TextField, 'Spielername'),
      'Max',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(find.text('5 Spieler im Turnier'), findsOneWidget);
    expect(find.text('Max'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('group-count-field')),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('group-count-field')),
      '3',
    );
    await tester.pumpAndSettle();

    expect(find.text('2 Spieler'), findsNWidgets(2));
    expect(find.text('1 Spieler'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('group-play-type-field'), skipOffstage: false),
      findsOneWidget,
    );
    expect(find.text('Jeder gegen jeden', skipOffstage: false), findsWidgets);

    await tester.enterText(
      find.byKey(const ValueKey('group-qualifier-count-field')),
      '4',
    );
    await tester.pumpAndSettle();

    expect(find.text('4 Weiterkommende'), findsOneWidget);
    expect(find.text('Top 1 je Gruppe'), findsOneWidget);
    expect(find.text('Beste 1 der 2. Plaetze'), findsOneWidget);
    expect(find.text('Zusatz aus Gruppe A, Gruppe B'), findsOneWidget);

    await tester.ensureVisible(
      find.byKey(const ValueKey('extra-group-chip-2'), skipOffstage: false),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('extra-group-chip-2')));
    await tester.pumpAndSettle();

    expect(find.text('Zusatz aus Gruppe A'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('stage-name-field'), skipOffstage: false),
      -400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('stage-name-field'), skipOffstage: false),
      'Vorrunde',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('1 Etappen im Turnier'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('1 Etappen im Turnier'), findsOneWidget);
    expect(find.text('Vorrunde'), findsOneWidget);
    expect(
      find.text(
        'Gruppen/Liga - Gruppe A: 2, Gruppe B: 2, Gruppe C: 1 - '
        'Spieltypen: Gruppe A Jeder gegen jeden, '
        'Gruppe B Jeder gegen jeden, Gruppe C Jeder gegen jeden - '
        'Begegnungen: Gruppe A 1x, Gruppe B 1x, Gruppe C 1x - '
        '2 Spiele - '
        '4 Weiterkommende - Top 1 je Gruppe + '
        'beste 1 2. Plaetze aus Gruppe A - '
        'Tie-Breaker: Punkte, Leg-Differenz, Gewonnene Legs, '
        'Direkter Vergleich',
      ),
      findsOneWidget,
    );

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('stage-type-field')),
      -400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gruppenphase'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('K.-o.-Runde').last);
    await tester.pumpAndSettle();

    expect(find.text('Uebernahme aus vorheriger Etappe'), findsOneWidget);
    expect(find.text('4 Weiter'), findsOneWidget);
    expect(find.text('4er Feld'), findsOneWidget);
    expect(find.text('0 Freilose'), findsOneWidget);
    expect(find.text('Cross seeded'), findsOneWidget);
    expect(find.text('Zufall'), findsOneWidget);
    expect(find.text('Bracket-Vorschau'), findsOneWidget);
    expect(find.text('Spiel 1'), findsWidgets);
    expect(find.text('Finale'), findsOneWidget);
    expect(find.text('1. Gruppe A'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('stage-name-field'), skipOffstage: false),
      'Endrunde',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('2 Etappen im Turnier'),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('2 Etappen im Turnier'), findsOneWidget);
    expect(find.text('Endrunde'), findsOneWidget);
    expect(
      find.text(
        'K.-o.-Runde - 4 Teilnehmer, 4er Feld, 0 Freilose - '
        'Cross seeded - '
        '3 Spiele - '
        '4 Weiterkommende - Top 1 je Gruppe + '
        'beste 1 2. Plaetze aus Gruppe A',
      ),
      findsOneWidget,
    );

    await tester.dragUntilVisible(
      find.text('Turnier anlegen'),
      find.byType(Scrollable).first,
      const Offset(0, -120),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Turnier anlegen'));
    await tester.pumpAndSettle();

    expect(find.text('Neues Turnier'), findsOneWidget);
    expect(find.text('Gruppe A'), findsWidgets);
    expect(find.text('Vergleich aus Gruppe A'), findsOneWidget);
    expect(find.text('Spiele'), findsWidgets);
    expect(find.text('Runde 1'), findsNothing);

    await tester.tap(find.text('2. Endrunde'));
    await tester.pumpAndSettle();

    expect(find.text('Turnierbaum'), findsOneWidget);
    expect(find.text('Spiel 1'), findsWidgets);
    expect(
      find.text(
        'Vorschau: Ergebnisse und Abschluss sind nur in der aktuellen Etappe "Vorrunde" moeglich.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('1. Vorrunde'));
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView).last, const Offset(0, -160));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Spiele').first);
    await tester.pumpAndSettle();

    expect(find.text('Runde 1'), findsWidgets);

    await tester.tap(find.text('Spielansicht'));
    await tester.pumpAndSettle();

    expect(find.text('Spielreihenfolge'), findsOneWidget);
    expect(find.text('Runde 1'), findsWidgets);

    await tester.tap(find.byTooltip('Ergebnis eingeben').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('home-legs-field')), '3');
    await tester.enterText(find.byKey(const ValueKey('away-legs-field')), '1');
    await tester.tap(find.text('Speichern'));
    await tester.pumpAndSettle();

    expect(find.text('3:1'), findsWidgets);

    await tester.ensureVisible(find.byTooltip('Ergebnis').at(1));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Ergebnis').at(1));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('home-legs-field')), '2');
    await tester.enterText(find.byKey(const ValueKey('away-legs-field')), '0');
    await tester.tap(find.text('Speichern'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Etappe abschliessen'));
    await tester.pumpAndSettle();

    expect(find.text('Endrunde'), findsOneWidget);
    expect(find.text('Spielreihenfolge'), findsOneWidget);
    expect(find.text('Anna'), findsWidgets);
    expect(find.text('Spieler 4'), findsNothing);

    await tester.tap(find.byIcon(Icons.view_agenda_outlined));
    await tester.pumpAndSettle();

    expect(find.text('Turnierbaum'), findsOneWidget);
    expect(find.text('Finale'), findsOneWidget);
  });
}
