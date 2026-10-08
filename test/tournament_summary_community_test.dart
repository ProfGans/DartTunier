import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_tournament_manager/features/tournaments/domain/tournament_models.dart';
import 'package:dart_tournament_manager/features/tournaments/presentation/widgets/tournament_summary_card.dart';

void main() {
  for (final size in [const Size(360, 800), const Size(800, 600), const Size(1440, 900)]) {
    testWidgets('community label at $size and large text', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      for (final community in <String?>['community-id', null]) {
        await tester.pumpWidget(MaterialApp(
          builder: (context, child) => MediaQuery(data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(2)), child: child!),
          home: Scaffold(body: SingleChildScrollView(child: TournamentSummaryCard(
            tournament: CreatedTournament(name: 'Neues Turnier', communityId: community,
              players: [], stages: [], runStages: []), onOpen: () {}, onDelete: () {},
          ))),
        ));
        expect(find.text('Community-Turnier'), community == null ? findsNothing : findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    });
  }
}
