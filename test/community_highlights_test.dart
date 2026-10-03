import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_tournament_manager/features/community_highlights/domain/community_highlight.dart';
import 'package:dart_tournament_manager/features/community_highlights/data/community_highlights_repository.dart';
import 'package:dart_tournament_manager/features/community_highlights/presentation/community_highlights_page.dart';
import 'package:dart_tournament_manager/features/community_highlights/presentation/highlight_editor_page.dart';
import 'package:dart_tournament_manager/features/statistics/domain/statistics_period.dart';
import 'package:dart_tournament_manager/features/tournaments/domain/tournament_models.dart';
import 'tournament_highlights_test.dart' show recordedMatch;

CommunityHighlight sampleHighlight({String key = 'manual:1'}) =>
    CommunityHighlight(
      key: key,
      category: HighlightCategory.checkout,
      title: 'Erstes 170er Finish',
      value: '170 Punkte',
      player: 'Alexandra mit langem Spielernamen',
      tournament: 'Vereinsmeisterschaft',
      date: DateTime(2026, 10, 3),
      note: 'Drei perfekte Darts',
    );

class FakeHighlightsRepository extends CommunityHighlightsRepository {
  FakeHighlightsRepository({this.manage = true, this.fail = false});
  bool manage, fail;
  final entries = [sampleHighlight()];
  @override
  Future<bool> canManage(String community) async => manage;
  @override
  Future<List<CommunityHighlight>> load(String community) async => [...entries];
  @override
  Future<CommunityHighlight> save(
    String community,
    CommunityHighlight highlight,
  ) async {
    if (fail || !manage) throw StateError('rejected');
    entries.removeWhere((h) => h.key == highlight.key);
    entries.add(highlight);
    return highlight;
  }
}

class CommunityHighlightsPreview extends StatelessWidget {
  const CommunityHighlightsPreview({super.key, this.repository});
  final FakeHighlightsRepository? repository;
  @override
  Widget build(BuildContext context) => CommunityHighlightsPage(
    communityId: 'club',
    communityName: 'Dartverein',
    tournaments: const [],
    repository: repository ?? FakeHighlightsRepository(),
  );
}

class HighlightEditorPreview extends StatelessWidget {
  const HighlightEditorPreview({super.key});
  @override
  Widget build(BuildContext context) => HighlightEditorPage(
    communityId: 'club',
    repository: FakeHighlightsRepository(),
    highlight: sampleHighlight(),
  );
}

void main() {
  const service = CommunityHighlights();
  test(
    'automatic data is community scoped, stable and updates from scorer corrections',
    () {
      final match = recordedMatch();
      final t = CreatedTournament(
        id: 't',
        communityId: 'club',
        name: 'Test',
        players: [],
        stages: [],
        runStages: [
          KnockoutTournamentRunStage(
            name: 'Finale',
            rounds: [
              [match],
            ],
          ),
        ],
      );
      expect(service.automatic('other', [t]), isEmpty);
      final first = service.automatic('club', [t, t]);
      expect(first, hasLength(3));
      final checkout = first.firstWhere(
        (h) => h.category == HighlightCategory.checkout,
      );
      expect(checkout.value, '120 Punkte');
      expect(service.merge(first, [checkout.removed()]).length, 2);
      expect(
        service
            .merge(first, [sampleHighlight(key: checkout.key)])
            .firstWhere((h) => h.key == checkout.key)
            .value,
        '170 Punkte',
      );
      match.deviceResult = null;
      expect(service.automatic('club', [t]), isEmpty);
      expect(service.merge([], [sampleHighlight(key: checkout.key)]), isEmpty);
      expect(service.merge([], [sampleHighlight()]), hasLength(1));
    },
  );
  test(
    'filters combine category, player, tournament, date, text and source',
    () {
      final entries = [sampleHighlight()];
      expect(
        service.filter(
          entries,
          query: 'perfekte',
          category: HighlightCategory.checkout,
          player: entries.first.player,
          tournament: entries.first.tournament,
          period: StatisticsPeriod(
            DateTime(2026, 10, 3),
            DateTime(2026, 10, 3),
          ),
          automatic: false,
        ),
        hasLength(1),
      );
      expect(service.filter(entries, automatic: true), isEmpty);
      expect(
        service.filter(entries, category: HighlightCategory.average),
        isEmpty,
      );
      expect(service.filter(entries, player: 'Other'), isEmpty);
      expect(service.filter(entries, tournament: 'Other'), isEmpty);
      expect(
        service.filter(
          entries,
          period: StatisticsPeriod(
            DateTime(2026, 10, 4),
            DateTime(2026, 10, 5),
          ),
        ),
        isEmpty,
      );
      expect(
        CommunityHighlight.fromJson(entries.first.toJson()).value,
        '170 Punkte',
      );
      expect(
        CommunityHighlight.fromJson(entries.first.removed().toJson()).deleted,
        isTrue,
      );
    },
  );
  testWidgets('reader can search but has no management menu', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CommunityHighlightsPreview(
          repository: FakeHighlightsRepository(manage: false),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Highlight hinzufügen'), findsNothing);
    expect(find.byTooltip('Highlight verwalten'), findsNothing);
    await tester.enterText(find.byType(TextField), 'nicht vorhanden');
    await tester.pumpAndSettle();
    expect(
      find.text('Keine Highlights für diese Filter vorhanden.'),
      findsOneWidget,
    );
  });
  testWidgets('editing replaces an existing highlight without duplication', (
    tester,
  ) async {
    final repository = FakeHighlightsRepository();
    await tester.pumpWidget(
      MaterialApp(home: CommunityHighlightsPreview(repository: repository)),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byTooltip('Highlight verwalten'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Highlight verwalten'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bearbeiten'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Wert / Leistung'),
      '160 Punkte',
    );
    await tester.scrollUntilVisible(
      find.text('Speichern'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Speichern'));
    await tester.pumpAndSettle();
    expect(repository.entries, hasLength(1));
    expect(repository.entries.single.key, 'manual:1');
    expect(repository.entries.single.value, '160 Punkte');
  });
  testWidgets('editor preserves input after denied save and can retry', (
    tester,
  ) async {
    final repository = FakeHighlightsRepository(fail: true);
    await tester.pumpWidget(
      MaterialApp(home: CommunityHighlightsPreview(repository: repository)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Highlight hinzufügen'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Titel'),
      'Neues Highlight',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Wert / Leistung'),
      '9 Darts',
    );
    await tester.scrollUntilVisible(
      find.text('Speichern'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Speichern'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Speichern nicht bestätigt'), findsOneWidget);
    repository.fail = false;
    await tester.scrollUntilVisible(
      find.text('Speichern'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Speichern'));
    await tester.pumpAndSettle();
    expect(repository.entries, hasLength(2));
    expect(repository.entries.last.title, 'Neues Highlight');
  });
  testWidgets('delete is confirmed and remains deleted after refresh', (
    tester,
  ) async {
    final repository = FakeHighlightsRepository();
    await tester.pumpWidget(
      MaterialApp(home: CommunityHighlightsPreview(repository: repository)),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byTooltip('Highlight verwalten'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Highlight verwalten'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Löschen'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Abbrechen'));
    await tester.pumpAndSettle();
    expect(repository.entries.single.deleted, isFalse);
    await tester.tap(find.byTooltip('Highlight verwalten'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Löschen'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Löschen'));
    await tester.pumpAndSettle();
    expect(repository.entries.single.deleted, isTrue);
    await tester.ensureVisible(find.text('Aktualisieren'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Aktualisieren'));
    await tester.pumpAndSettle();
    expect(find.text('Erstes 170er Finish'), findsNothing);
  });
  for (final size in [
    const Size(360, 800),
    const Size(800, 600),
    const Size(1440, 900),
  ]) {
    testWidgets('highlight list and editor at $size with large text', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: const CommunityHighlightsPreview(),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Highlight hinzufügen'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Titel'),
        'Erhalten',
      );
      await tester.binding.setSurfaceSize(const Size(800, 600));
      await tester.pumpAndSettle();
      expect(find.text('Erhalten'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
