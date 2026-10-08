import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_tournament_manager/features/accounts/domain/account_user.dart';
import 'package:dart_tournament_manager/features/tournaments/application/tournament_player_choices.dart';
import 'package:dart_tournament_manager/features/tournaments/data/app_database.dart';
import 'package:dart_tournament_manager/features/tournaments/presentation/widgets/creation/player_profile_picker_dialog.dart';

void main() {
  final date = DateTime.utc(2026);
  final account = AccountUser(
    id: 'online-account',
    username: 'johannes',
    displayName: 'Johannes',
    email: '',
    avatarUrl: null,
    createdAt: date,
    updatedAt: date,
    lastLogin: null,
    isActive: true,
  );
  final local = PlayerProfile(
    id: 'local-profile',
    userId: account.id,
    displayName: 'Johannes lokal',
    country: '',
    city: '',
    dartsSetupJson: '',
    createdAt: date,
    isActive: true,
  );
  test('online account is selectable without a local player profile', () {
    final choices = tournamentPlayerChoices([], account);
    expect(choices.single.id, account.id);
    expect(choices.single.userId, account.id);
    expect(choices.single.displayName, account.displayName);
    expect(tournamentPlayerChoices(choices, account).length, 1);
  });
  test('existing profile identity is preserved and no guest is invented', () {
    expect(tournamentPlayerChoices([local], account).single, same(local));
    expect(tournamentPlayerChoices([], null), isEmpty);
    expect(tournamentPlayerChoices([local], null).single, same(local));
  });
  for (final size in [
    const Size(360, 800),
    const Size(800, 600),
    const Size(1440, 900),
  ]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('select self at $size / $scale', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        List<PlayerProfile>? selected;
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () async {
                    selected = await showDialog<List<PlayerProfile>>(
                      context: context,
                      builder: (_) => PlayerProfilePickerDialog(
                        profiles: tournamentPlayerChoices([], account),
                        selectedProfileIds: const {},
                        currentUserId: account.id,
                      ),
                    );
                  },
                  child: const Text('Auswählen'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Auswählen'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Johannes (Du)'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('1 uebernehmen'));
        await tester.pumpAndSettle();
        expect(selected!.single.id, account.id);
        expect(selected!.single.displayName, 'Johannes');
        expect(tester.takeException(), isNull);
      });
    }
  }
}
