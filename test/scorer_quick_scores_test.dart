import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_tournament_manager/features/scorer/presentation/widgets/score_keypad.dart';

void main() {
  testWidgets('Every preset submits immediately once', (tester) async {
    final scores = <int>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ScoreKeypad(
            enabled: true,
            remaining: 501,
            onBust: () {},
            onSubmit: (value) async {
              scores.add(value);
              return true;
            },
          ),
        ),
      ),
    );
    for (final value in [26, 41, 60, 81, 100, 140, 180]) {
      await tester.tap(find.text('$value'));
      await tester.pumpAndSettle();
    }
    expect(scores, [26, 41, 60, 81, 100, 140, 180]);
  });
  testWidgets(
    'Pending submission blocks repeated taps; digits still require OK',
    (tester) async {
      final pending = Completer<bool>();
      final scores = <int>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ScoreKeypad(
              enabled: true,
              remaining: 501,
              onBust: () {},
              onSubmit: (value) {
                scores.add(value);
                return pending.future;
              },
            ),
          ),
        ),
      );
      await tester.tap(find.text('1'));
      await tester.pump();
      expect(scores, isEmpty);
      await tester.tap(find.text('OK'));
      await tester.pump();
      await tester.tap(find.text('100'));
      await tester.pump();
      expect(scores, [1]);
      pending.complete(true);
      await tester.pumpAndSettle();
    },
  );
}
