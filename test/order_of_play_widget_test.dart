import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_tournament_manager/features/tournaments/domain/tournament_models.dart';
import 'package:dart_tournament_manager/features/tournaments/presentation/widgets/run/order_of_play_section.dart';
import 'package:dart_tournament_manager/features/tournaments/presentation/widgets/run/stage_controls.dart';

void main() {
  testWidgets('third tab and start action work on a narrow screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final players = [
      TournamentPlayer.generated(1),
      TournamentPlayer.generated(2),
    ];
    final match = GroupMatch(
      homePlayer: players[0],
      awayPlayer: players[1],
      round: 1,
    );
    final tournament = CreatedTournament(
      name: 'Test',
      players: players,
      stages: [],
      runStages: [
        GroupTournamentRunStage(
          name: 'Gruppe',
          groupPlayType: 'round_robin',
          qualificationPlan: null,
          tieBreakers: defaultGroupTieBreakers,
          groups: [
            TournamentGroup(
              name: 'A',
              playType: 'round_robin',
              players: players,
              matches: [match],
            ),
          ],
        ),
      ],
    );
    var mode = StageViewMode.overview;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) => Scaffold(
            body: SafeArea(
              child: Column(
                children: [
                  StageViewModeSwitch(
                    selectedMode: mode,
                    onModeChanged: (value) => setState(() => mode = value),
                  ),
                  if (mode == StageViewMode.orderOfPlay)
                    Expanded(
                      child: SingleChildScrollView(
                        child: OrderOfPlaySection(
                          tournament: tournament,
                          activeStage: 0,
                          onChange: () async {
                            setState(() {});
                          },
                          onResult: (_) async {},
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Order of Play'));
    await tester.pumpAndSettle();
    expect(find.text('Verfügbare Boards'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.byTooltip('Starten / vorziehen'));
    await tester.tap(find.byTooltip('Starten / vorziehen'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Auf Board 1 starten'));
    await tester.pumpAndSettle();
    expect(match.boardNumber, 1);
    expect(match.startedAt, isNotNull);
    expect(find.byTooltip('Match verwalten'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
