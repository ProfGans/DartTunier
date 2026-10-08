import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_tournament_manager/features/statistics/domain/analytics/community_profile_reports.dart';
import 'package:dart_tournament_manager/features/statistics/domain/analytics/statistics_report.dart';
import 'package:dart_tournament_manager/features/statistics/presentation/analytics/player_analytics_page.dart';
import 'package:dart_tournament_manager/features/statistics/presentation/analytics/statistics_dashboard.dart';
import 'community_tournament_elo_test.dart' show eloTournament;

void main() {
  const font = String.fromEnvironment('LAYOUT_PREVIEW_FONT');
  setUpAll(() async {
    if (font.isNotEmpty) {
      await (FontLoader('Roboto')..addFont(
            Future.value(ByteData.sublistView(await File(font).readAsBytes())),
          ))
          .load();
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    }
  });
  test('community provenance, aliases, ownership and duplicates', () {
    final tournament = eloTournament(completed: true);
    final reports = communityProfileReports(
      tournaments: [tournament, tournament],
      tournamentCommunities: {tournament.id: 'club'},
      ownIds: {'account'},
      aliases: {'a': 'account'},
      communities: {'empty'},
    );
    expect(reports['club']!.observations.length, 1);
    expect(reports['club']!.observations.single.playerId, 'account');
    expect(reports['empty']!.observations, isEmpty);
    expect(
      communityProfileReports(
        tournaments: [tournament],
        tournamentCommunities: {},
        ownIds: {'account'},
      ).values.expand((r) => r.observations),
      isEmpty,
    );
  });
  for (final size in [
    const Size(360, 800),
    const Size(800, 600),
    const Size(1440, 900),
  ]) {
    testWidgets('community source and filters at $size', (tester) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      StatisticsReport report(String id, {bool doubles = false}) =>
          StatisticsReport([
            StatisticsObservation(
              id: id,
              playerId: 'own',
              name: 'Anna',
              label: 'Begegnung $id',
              date: DateTime.now(),
              values: {'matches': 1, 'wins': 1},
              result: 'S',
              doubleMatch: doubles,
            ),
          ]);
      final previewKey = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: RepaintBoundary(
            key: previewKey,
            child: PlayerAnalyticsPage(
              name: 'Anna',
              scorer: report('private'),
              tournaments: report('local'),
              communityNames: const {'a': 'Dartclub A', 'b': 'Dartclub B'},
              communityReports: {
                'a': report('a'),
                'b': report('b', doubles: true),
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Statistikbereich'), 200);
      await Scrollable.ensureVisible(
        tester.element(find.byType(DropdownButtonFormField<int>).first),
        alignment: .5,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<int>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Community-Spiele').last);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.byType(StatisticsDashboard), 200);
      expect(
        tester
            .widget<StatisticsDashboard>(find.byType(StatisticsDashboard))
            .report
            .observations
            .map((o) => o.id),
        ['a', 'b'],
      );
      await tester.scrollUntilVisible(find.text('Community filtern'), -200);
      await Scrollable.ensureVisible(
        tester.element(find.byType(DropdownButtonFormField<String>)),
        alignment: .5,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dartclub B').last);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.byType(StatisticsDashboard), 200);
      expect(
        tester
            .widget<StatisticsDashboard>(find.byType(StatisticsDashboard))
            .report
            .observations
            .single
            .id,
        'b',
      );
      if (font.isNotEmpty) {
        await tester.scrollUntilVisible(find.text('Community filtern'), -200);
        await Scrollable.ensureVisible(
          tester.element(find.byType(DropdownButtonFormField<String>)),
          alignment: .3,
        );
        await tester.pumpAndSettle();
        await tester.runAsync(() async {
          final picture =
              await (previewKey.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary)
                  .toImage();
          final data = await picture.toByteData(format: ui.ImageByteFormat.png);
          final file = File(
            'build/layout_previews/community_profile_filter_${size.width.toInt()}.png',
          );
          await file.parent.create(recursive: true);
          await file.writeAsBytes(data!.buffer.asUint8List());
          picture.dispose();
        });
      }
      await tester.scrollUntilVisible(find.byType(StatisticsDashboard), 200);
      await tester.binding.setSurfaceSize(const Size(800, 600));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<StatisticsDashboard>(find.byType(StatisticsDashboard))
            .report
            .observations
            .single
            .id,
        'b',
      );
      expect(tester.takeException(), isNull);
    });
  }
}
