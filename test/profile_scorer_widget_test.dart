import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_tournament_manager/features/statistics/data/player_statistics_repository.dart';
import 'package:dart_tournament_manager/features/statistics/domain/saved_scorer_match.dart';
import 'package:dart_tournament_manager/features/scorer/presentation/scorer_match_page.dart';
import 'package:dart_tournament_manager/features/scorer/domain/scorer_settings.dart';

class _MemoryStatistics extends PlayerStatisticsRepository {
  final records = <String, SavedScorerMatch>{};
  bool fail = false;
  @override
  Future<void> save(SavedScorerMatch match) async {
    if (fail) throw StateError('disk full');
    records[match.id] = match;
  }

  @override
  Future<void> synchronize(String accountId) async {}
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets('profile scorer persists completion, undo, and waits on exit', (
    tester,
  ) async {
    final repository = _MemoryStatistics();
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => ScorerMatchPage(
                    accountId: 'anna',
                    profilePlayerIndex: 0,
                    statisticsRepository: repository,
                    settings: ScorerSettings(
                      startScore: 40,
                      bestOfLegs: 1,
                      participants: const [
                        ScorerParticipant('Anna'),
                        ScorerParticipant('Ben'),
                      ],
                    ),
                  ),
                ),
              ),
              child: const Text('Start'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Start'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('4'));
    await tester.pump();
    await tester.tap(find.text('0'));
    await tester.pump();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('1 Dart'));
    await tester.pumpAndSettle();
    expect(repository.records.values.single.accountId, 'anna');
    expect(repository.records.values.single.winner, 0);
    expect(repository.records.values.single.statistics.highestFinish, 40);
    await tester.scrollUntilVisible(
      find.byTooltip('Rückgängig'),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    await Scrollable.ensureVisible(
      tester.element(find.byTooltip('Rückgängig')),
      alignment: .5,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Rückgängig'));
    await tester.pumpAndSettle();
    expect(repository.records, hasLength(1));
    expect(repository.records.values.single.winner, isNull);
    expect(repository.records.values.single.visits, isEmpty);
    repository.fail = true;
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ohne Speichern verlassen'));
    await tester.pumpAndSettle();
    expect(find.text('Erneut speichern'), findsOneWidget);
    expect(find.byType(ScorerMatchPage), findsOneWidget);
    repository.fail = false;
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ohne Speichern verlassen'));
    await tester.pumpAndSettle();
    expect(find.text('Start'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
