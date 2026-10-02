import 'package:dart_tournament_manager/features/statistics/presentation/statistics_date_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_tournament_manager/features/statistics/domain/statistics_period.dart';
import 'package:dart_tournament_manager/features/statistics/presentation/statistics_period_filter.dart';

void main() {
  test(
    'inclusive local days, UTC instants, month boundaries and unknown dates',
    () {
      final period = StatisticsPeriod(
        DateTime(2026, 3, 29, 12),
        DateTime(2026, 3, 31),
      );
      expect(period.contains(DateTime(2026, 3, 29).toUtc()), isTrue);
      expect(period.contains(DateTime(2026, 3, 31, 23, 59, 59)), isTrue);
      expect(period.contains(DateTime(2026, 4, 1)), isFalse);
      expect(period.contains(DateTime(2026, 3, 28, 23, 59)), isFalse);
      expect(period.contains(null), isFalse);
    },
  );

  testWidgets(
    'presets apply and custom dialog cancellation preserves selection',
    (tester) async {
      String selected = 'Gesamt';
      StatisticsPeriod? period;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => StatisticsPeriodFilter(
                selected: selected,
                period: period,
                onChanged: (label, value) => setState(() {
                  selected = label;
                  period = value;
                }),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('7 Tage'));
      await tester.pumpAndSettle();
      final now = DateTime.now();
      expect(period!.contains(now), isTrue);
      expect(
        period!.contains(DateTime(now.year, now.month, now.day - 7)),
        isFalse,
      );
      await tester.tap(find.text('Zeitraum wählen'));
      await tester.pumpAndSettle();
      expect(find.byType(StatisticsDateDialog), findsOneWidget);
      final context = tester.element(find.byType(StatisticsDateDialog));
      Navigator.pop(context);
      await tester.pumpAndSettle();
      expect(selected, '7 Tage');
      await tester.tap(find.text('Zeitraum wählen'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).first, '31.02.2024');
      await tester.enterText(find.byType(TextFormField).last, '01.03.2024');
      await tester.tap(find.text('Anwenden'));
      await tester.pumpAndSettle();
      expect(
        find.text('Gültiges Datum als TT.MM.JJJJ eingeben.'),
        findsOneWidget,
      );
      await tester.enterText(find.byType(TextFormField).first, '29.02.2024');
      await tester.enterText(find.byType(TextFormField).last, '28.02.2024');
      await tester.tap(find.text('Anwenden'));
      await tester.pumpAndSettle();
      expect(
        find.text('Ende darf nicht vor dem Beginn liegen.'),
        findsOneWidget,
      );
      await tester.enterText(find.byType(TextFormField).last, '01.03.2024');
      await tester.tap(find.text('Anwenden'));
      await tester.pumpAndSettle();
      expect(period!.contains(DateTime(2024, 2, 29)), isTrue);
      expect(period!.contains(DateTime(2024, 3, 1, 23, 59)), isTrue);
      expect(period!.contains(DateTime(2024, 3, 2)), isFalse);
      await tester.tap(find.text('Gesamt'));
      await tester.pumpAndSettle();
      expect(period, isNull);
    },
  );
}
