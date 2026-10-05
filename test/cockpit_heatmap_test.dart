import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_tournament_manager/features/scorer/domain/scorer_hit.dart';
import 'package:dart_tournament_manager/features/statistics/data/scorer_heatmap_repository.dart';
import 'package:dart_tournament_manager/features/statistics/domain/cockpit_heatmap_selection.dart';
import 'package:dart_tournament_manager/features/statistics/domain/saved_scorer_match.dart';
import 'package:dart_tournament_manager/features/statistics/domain/statistics_period.dart';
import 'package:dart_tournament_manager/features/statistics/presentation/heatmap/cockpit_heatmap_section.dart';
import 'package:dart_tournament_manager/features/statistics/presentation/heatmap/scorer_heatmap_page.dart';
import 'package:dart_tournament_manager/features/statistics/presentation/heatmap/scorer_heatmap_view.dart';

ScorerHit hit(int player, {bool estimated = false, bool checkout = false}) =>
    ScorerHit(
      location: DartLocation(12, -100, estimated: estimated),
      player: player,
      leg: 0,
      thrower: 'Gleicher Name',
      label: 'T20',
      points: 60,
      checkoutAttempt: checkout,
    );
final session = ScorerHeatmapSession(
  id: 'own',
  date: DateTime(2026, 10, 4),
  names: ['Anna', 'Ben'],
  hits: [hit(0, checkout: true), hit(0, estimated: true), hit(1)],
);

void main() {
  const font = String.fromEnvironment('LAYOUT_PREVIEW_FONT');
  setUpAll(() async {
    if (font.isNotEmpty) {
      final loader = FontLoader('Roboto')
        ..addFont(
          Future.value(ByteData.sublistView(await File(font).readAsBytes())),
        );
      await loader.load();
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    }
  });
  test('profile joins by session ID and participant index, never name', () {
    final match = SavedScorerMatch(
      id: 'own',
      accountId: 'account',
      playedAt: DateTime(2026, 10, 4),
      playerIndex: 0,
      names: ['Anna', 'Ben'],
      startScores: [501, 501],
      standard501Rules: true,
      doubleOut: true,
      visits: [],
    );
    final unrelated = ScorerHeatmapSession(
      id: 'other',
      date: session.date,
      names: session.names,
      hits: [hit(0)],
    );
    final result = selectProfileHeatmaps([session, unrelated], [match]);
    expect(result.length, 1);
    expect(result.single.hits.length, 2);
    expect(result.single.hits.every((h) => h.player == 0), isTrue);
    expect(result.single.names, ['Anna']);
    expect(selectProfileHeatmaps([session], []), isEmpty);
  });
  for (final size in [
    const Size(360, 800),
    const Size(800, 600),
    const Size(1440, 900),
  ]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'large heatmap filters and detail navigation at $size scale $scale',
        (tester) async {
          await tester.binding.setSurfaceSize(size);
          addTearDown(() => tester.binding.setSurfaceSize(null));
          final key = GlobalKey();
          await tester.pumpWidget(
            MaterialApp(
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: Scaffold(
                body: SingleChildScrollView(
                  child: RepaintBoundary(
                    key: key,
                    child: CockpitHeatmapSection(
                      subject: 'Anna Beispiel mit langem Profilnamen',
                      sessions: [session],
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.byType(ScorerHeatmapView), findsOneWidget);
          expect(find.text('3 lokalisierte Darts'), findsOneWidget);
          expect(tester.takeException(), isNull);
          if (font.isNotEmpty) {
            await tester.runAsync(() async {
              final picture =
                  await (key.currentContext!.findRenderObject()!
                          as RenderRepaintBoundary)
                      .toImage();
              final data = await picture.toByteData(
                format: ui.ImageByteFormat.png,
              );
              final file = File(
                'build/layout_previews/cockpit_heatmap_${size.width.toInt()}_$scale.png',
              );
              await file.parent.create(recursive: true);
              await file.writeAsBytes(data!.buffer.asUint8List());
              picture.dispose();
            });
          }
          await tester.ensureVisible(find.text('Schätzungen einschließen'));
          await tester.tap(find.text('Schätzungen einschließen'));
          await tester.pumpAndSettle();
          expect(find.text('2 lokalisierte Darts'), findsOneWidget);
          await tester.ensureVisible(find.text('Nur Checkoutversuche'));
          await tester.tap(find.text('Nur Checkoutversuche'));
          await tester.pumpAndSettle();
          expect(find.text('1 lokalisierter Dart'), findsOneWidget);
          await tester.ensureVisible(find.text('Heatmap im Detail'));
          await tester.tap(find.text('Heatmap im Detail'));
          await tester.pumpAndSettle();
          expect(find.byType(ScorerHeatmapPage), findsOneWidget);
          expect(
            tester
                .widget<ScorerHeatmapPage>(find.byType(ScorerHeatmapPage))
                .sessions!
                .single
                .hits
                .length,
            1,
          );
          await tester.pageBack();
          await tester.pumpAndSettle();
          await tester.binding.setSurfaceSize(const Size(800, 600));
          await tester.pumpAndSettle();
          expect(find.text('1 lokalisierter Dart'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
  testWidgets('period and empty community do not display unrelated hits', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: CockpitHeatmapSection(
              subject: 'Anna',
              sessions: [session],
              period: StatisticsPeriod(DateTime(2025), DateTime(2025, 2)),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('0 lokalisierte Darts'), findsOneWidget);
    expect(find.byType(ScorerHeatmapView), findsNothing);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: CockpitHeatmapSection(subject: 'Community', community: true),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Private lokale Heatmaps'), findsOneWidget);
    expect(find.byType(ScorerHeatmapView), findsNothing);
  });
}
