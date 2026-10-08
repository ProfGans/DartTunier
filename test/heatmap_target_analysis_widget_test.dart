import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_tournament_manager/features/scorer/presentation/widgets/heatmap_target_picker.dart';
import 'package:dart_tournament_manager/features/scorer/domain/scorer_hit.dart';
import 'package:dart_tournament_manager/features/statistics/data/scorer_heatmap_repository.dart';
import 'package:dart_tournament_manager/features/statistics/presentation/heatmap/heatmap_target_analysis.dart';

void main() {
  for (final size in [
    const Size(360, 800),
    const Size(800, 600),
    const Size(1440, 900),
  ]) {
    testWidgets('optional target picker at $size and text 200%', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      String? target = 'D20';
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MediaQuery(
              data: MediaQueryData(
                size: size,
                textScaler: const TextScaler.linear(2),
              ),
              child: SingleChildScrollView(
                child: StatefulBuilder(
                  builder: (context, update) => Padding(
                    padding: const EdgeInsets.all(16),
                    child: HeatmapTargetPicker(
                      target: target,
                      player: 0,
                      onChanged: (value) => update(() => target = value),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Heatmap-Ziel: D20'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byType(DropdownButtonFormField<String>));
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('D19').last);
      await tester.pumpAndSettle();
      expect(target, 'D19');
      expect(find.text('Heatmap-Ziel: D19'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
    testWidgets('target and development analysis at $size and text 200%', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final hit = ScorerHit(
        location: const DartLocation(0, -166),
        player: 0,
        leg: 1,
        thrower: 'Anna',
        label: 'D20',
        points: 40,
        checkoutAttempt: true,
        targetLabel: 'D20',
        thrownAt: DateTime.now().toUtc(),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MediaQuery(
              data: MediaQueryData(
                size: size,
                textScaler: const TextScaler.linear(2),
              ),
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: HeatmapTargetAnalysis(
                    hits: [hit],
                    favoriteDouble: '20',
                    compare: true,
                    sessions: [
                      ScorerHeatmapSession(
                        id: 'one',
                        date: DateTime.now(),
                        names: const ['Anna'],
                        hits: [hit],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Vorherige 28 Tage'), findsOneWidget);
      expect(find.text('Letzte 28 Tage'), findsOneWidget);
      expect(find.text('D20 · Lieblingsdoppel'), findsOneWidget);
      expect(find.text('1/1 im Zielsegment · 100.0 %'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
