import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_tournament_manager/main.dart';

void main() {
  testWidgets('places can be selected independently in creation', (tester) async {
    await tester.pumpWidget(const DartTournamentApp());
    await tester.tap(find.text('Turniere'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Turnier erstellen'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Anzahl'), '16');
    await tester.tap(find.text('Spieler erzeugen'));
    await tester.pumpAndSettle();
    final type = find.byKey(const ValueKey('stage-type-field'));
    await tester.scrollUntilVisible(type, 300, scrollable: find.byType(Scrollable).first);
    await tester.tap(type);
    await tester.pumpAndSettle();
    await tester.tap(find.text('K.-o.-Runde').last);
    await tester.pumpAndSettle();
    for (final place in [5, 7, 15]) {
      final chip = find.widgetWithText(FilterChip, 'Platz $place');
      await tester.ensureVisible(chip);
      await tester.tap(chip);
      await tester.pumpAndSettle();
      expect(tester.widget<FilterChip>(chip).selected, isTrue);
    }
    expect(tester.widget<FilterChip>(find.widgetWithText(FilterChip, 'Platz 3')).selected, isFalse);
  });

  testWidgets('placement tree renders beyond seventh place after restoring', (tester) async {
    final players = List.generate(16, (i) => TournamentPlayer.generated(i + 1));
    const config = TournamentStage(name: 'KO', type: 'single_knockout', placementPlaces: [3, 5, 7, 9, 15]);
    final tournament = CreatedTournament(name: 'Platzierungen', players: players, stages: [config], runStages: []);
    final runtime = ProductionTournamentRuntime(tournament);
    tournament.runStages.add(runtime.build(config, players));
    final loaded = CreatedTournament.fromJson(tournament.toJson());
    await tester.pumpWidget(MaterialApp(home: TournamentRunPage(tournament: loaded)));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Platzierungsspiele', skipOffstage: false), 500,
        scrollable: find.byType(Scrollable).first, maxScrolls: 50);
    expect(find.text('Platzierungsspiele'), findsOneWidget);
    expect(find.text('Spiel um Platz 15', skipOffstage: false), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
