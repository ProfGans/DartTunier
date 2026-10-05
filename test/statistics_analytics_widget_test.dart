import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_tournament_manager/features/statistics/domain/analytics/statistics_report.dart';
import 'package:dart_tournament_manager/features/statistics/domain/analytics/statistics_metric.dart';
import 'package:dart_tournament_manager/features/statistics/presentation/analytics/player_analytics_page.dart';
import 'package:dart_tournament_manager/features/statistics/presentation/analytics/statistics_metric_page.dart';
import 'package:dart_tournament_manager/features/communities/presentation/community_analytics_page.dart';
import 'package:dart_tournament_manager/app/app_theme.dart';
import 'statistics_analytics_test.dart' show analyticsMatch;
import 'community_statistics_navigation_test.dart' show statisticsFixture;

StatisticsReport analyticsFixture() => const StatisticsAnalytics().scorer([
  for (var i = 1; i <= 12; i++)
    analyticsMatch(
      id: '$i',
      points: i.isEven ? 180 : 60,
      winner: i % 3 == 0 ? 1 : 0,
    ),
]);

class PlayerAnalyticsPreview extends StatelessWidget {
  const PlayerAnalyticsPreview({super.key});
  @override
  Widget build(BuildContext context) => PlayerAnalyticsPage(
    name: 'Alexandra mit sehr langem Spielernamen',
    tournaments: analyticsFixture(),
    scorer: analyticsFixture(),
  );
}

class CommunityAnalyticsPreview extends StatelessWidget {
  const CommunityAnalyticsPreview({super.key});
  @override
  Widget build(BuildContext context) =>
      CommunityAnalyticsPage(name: 'Dartclub', data: statisticsFixture());
}

class MetricAnalyticsPreview extends StatelessWidget {
  const MetricAnalyticsPreview({super.key});
  @override
  Widget build(BuildContext context) => StatisticsMetricPage(
    report: analyticsFixture(),
    metric: statisticsMetrics.firstWhere((m) => m.title == '3-Dart-Average'),
    subject: 'Alexandra',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const font = String.fromEnvironment('LAYOUT_PREVIEW_FONT');
  setUpAll(() async {
    if (font.isNotEmpty) {
      await (FontLoader('Roboto')..addFont(
            File(font).readAsBytes().then((b) => ByteData.sublistView(b)),
          ))
          .load();
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    }
  });
  for (final size in [
    const Size(360, 800),
    const Size(800, 600),
    const Size(1440, 900),
  ]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('analytics pages $size text $scale', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        for (final page in [
          const PlayerAnalyticsPreview(),
          const CommunityAnalyticsPreview(),
          const MetricAnalyticsPreview(),
        ]) {
          await tester.pumpWidget(
            RepaintBoundary(
              key: const ValueKey('preview'),
              child: MaterialApp(
                theme: buildDartTournamentTheme(),
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!,
                ),
                home: page,
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          if (font.isNotEmpty) {
            await tester.runAsync(() async {
              final boundary = tester.renderObject<RenderRepaintBoundary>(
                find.byKey(const ValueKey('preview')),
              );
              final image = await boundary.toImage();
              final bytes = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              image.dispose();
              Directory('build/layout_previews').createSync(recursive: true);
              await File(
                'build/layout_previews/${page.runtimeType}_${size.width}_$scale.png',
              ).writeAsBytes(bytes!.buffer.asUint8List());
            });
          }
          if (font.isNotEmpty && page is MetricAnalyticsPreview) {
            await tester.scrollUntilVisible(
              find.text('Verlauf'),
              250,
              scrollable: find.byType(Scrollable).first,
            );
            await Scrollable.ensureVisible(
              tester.element(find.text('Verlauf')),
              alignment: 0,
            );
            await tester.pumpAndSettle();
            await tester.runAsync(() async {
              final boundary = tester.renderObject<RenderRepaintBoundary>(
                find.byKey(const ValueKey('preview')),
              );
              final image = await boundary.toImage();
              final bytes = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              image.dispose();
              await File(
                'build/layout_previews/MetricAnalyticsChart_${size.width}_$scale.png',
              ).writeAsBytes(bytes!.buffer.asUint8List());
            });
          }
          for (var i = 0; i < 12; i++) {
            await tester.drag(
              find.byType(ListView).first,
              const Offset(0, -400),
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
          }
          await tester.pumpWidget(const SizedBox());
          await tester.pumpAndSettle();
        }
      });
    }
  }
  testWidgets('all metric details render with large text and no data', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final metric in statisticsMetrics) {
      for (final report in [analyticsFixture(), StatisticsReport([])]) {
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(2)),
              child: child!,
            ),
            home: StatisticsMetricPage(
              report: report,
              metric: metric,
              subject: 'Spieler',
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        for (var i = 0; i < 10; i++) {
          await tester.drag(find.byType(ListView).first, const Offset(0, -500));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      }
    }
  });
  testWidgets('metric opens from dashboard and period survives resizing', (
    tester,
  ) async {
    await tester.pumpWidget(MaterialApp(home: const PlayerAnalyticsPreview()));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Spiele im Detail'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await Scrollable.ensureVisible(
      tester.element(find.text('Spiele im Detail')),
      alignment: .5,
    );
    await tester.pumpAndSettle();
    for (
      var attempt = 0;
      attempt < 15 &&
          find.text('Spiele im Detail').hitTestable().evaluate().isEmpty;
      attempt++
    ) {
      await tester.drag(find.byType(ListView), const Offset(0, -200));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('Spiele im Detail'));
    await tester.pumpAndSettle();
    expect(find.byType(StatisticsMetricPage), findsOneWidget);
    await Scrollable.ensureVisible(
      tester.element(find.text('Dieses Jahr')),
      alignment: .5,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dieses Jahr'));
    await tester.pumpAndSettle();
    await tester.binding.setSurfaceSize(const Size(360, 800));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Dieses Jahr'))
          .selected,
      isTrue,
    );
    addTearDown(() => tester.binding.setSurfaceSize(null));
    expect(tester.takeException(), isNull);
  });
}
