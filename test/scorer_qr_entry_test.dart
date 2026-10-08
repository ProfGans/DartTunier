import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:dart_tournament_manager/features/scorer/application/scorer_lobby_controller.dart';
import 'package:dart_tournament_manager/features/scorer/presentation/lobby/scorer_lobby_panel.dart';
import 'support/scorer_lobby_fake.dart';

void main() {
  for (final signedIn in [false, true]) {
    testWidgets('QR entry remains visible, signed in: $signedIn', (
      tester,
    ) async {
      final repo = FakeScorerLobbyRepository()
        ..currentUser = signedIn ? 'host' : null;
      final controller = ScorerLobbyController(repo);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ScorerLobbyPanel(controller: controller),
            ),
          ),
        ),
      );
      await tester.tap(find.text('QR-Code & Einladungen öffnen'));
      await tester.pumpAndSettle();
      if (signedIn) {
        expect(find.byType(QrImageView), findsOneWidget);
        expect(find.textContaining('Beitrittscode:'), findsOneWidget);
      } else {
        expect(find.text('Für den QR-Code online anmelden'), findsOneWidget);
        expect(find.byType(QrImageView), findsNothing);
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    });
  }
}
