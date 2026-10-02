import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_tournament_manager/features/league/data/league_invitation_repository.dart';
import 'package:dart_tournament_manager/features/league/presentation/league_match_page.dart';
import 'package:dart_tournament_manager/features/league/presentation/league_invitation_listener.dart';
import 'package:dart_tournament_manager/features/league/presentation/league_player_picker.dart';
import 'package:dart_tournament_manager/features/scorer/domain/scorer_lobby.dart';
import 'package:dart_tournament_manager/features/tournaments/data/app_database.dart';
import 'package:dart_tournament_manager/features/tournaments/data/tournament_storage.dart';
import 'package:dart_tournament_manager/features/tournaments/domain/tournament_models.dart';

class FakeInvitations extends LeagueInvitationRepository {
  Map<String, dynamic>? row;
  @override
  String? get userId => 'user';
  @override
  Future<List<ScorerInviteCandidate>> candidates() async => [
    const ScorerInviteCandidate('member', 'Anna', 'Verein'),
  ];
  @override
  Future<Map<String, dynamic>> invite(
    String match,
    String title,
    int team,
    int slot,
    String user,
  ) async => row = {
    'id': 'invitation',
    'user_id': user,
    'display_name': 'Anna',
    'team': team,
    'slot': slot,
    'title': title,
    'status': 'pending',
  };
  @override
  Future<List<Map<String, dynamic>>> status(String match) async => [?row];
  @override
  Future<List<Map<String, dynamic>>> inbox() async => [
    if (row?['status'] == 'pending') row!,
  ];
  @override
  Future<void> respond(String id, bool accept) async {
    row!['status'] = accept ? 'accepted' : 'declined';
  }

  @override
  Future<void> close(String match) async {}
}

class EmptyPlayers extends LocalAppDatabase {
  @override
  Future<List<PlayerProfile>> loadPlayerProfiles() async => [];
}

class LocalPlayers extends EmptyPlayers {
  @override
  Future<List<PlayerProfile>> loadPlayerProfiles() async => [
    PlayerProfile(
      id: 'local',
      userId: null,
      displayName: 'Lokal Anna',
      country: '',
      city: '',
      dartsSetupJson: '',
      createdAt: DateTime(2026),
      isActive: true,
    ),
  ];
}

class MemoryStorage extends TournamentStorage {
  CreatedTournament? saved;
  @override
  Future<void> saveTournament(CreatedTournament value) async {
    saved = CreatedTournament.fromJson(value.toJson());
  }
}

void main() {
  testWidgets(
    'local player search preserves profile and requires no invitation',
    (tester) async {
      LeaguePlayerChoice? selected;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                child: const Text('Öffnen'),
                onPressed: () async {
                  selected = await showDialog<LeaguePlayerChoice>(
                    context: context,
                    builder: (_) => LeaguePlayerPicker(
                      repository: FakeInvitations(),
                      database: LocalPlayers(),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Öffnen'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'anna');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lokal Anna'));
      await tester.pumpAndSettle();
      expect(selected!.player.profileId, 'local');
      expect(selected!.inviteUserId, isNull);
    },
  );
  testWidgets('community candidate is only adopted after acceptance', (
    tester,
  ) async {
    final repo = FakeInvitations();
    final storage = MemoryStorage();
    await tester.pumpWidget(
      MaterialApp(
        home: LeagueMatchPage(
          invitations: repo,
          database: EmptyPlayers(),
          storage: storage,
        ),
      ),
    );
    final select = find.text('Community-Mitglied einladen').first;
    await tester.ensureVisible(select);
    await tester.pumpAndSettle();
    await tester.tap(select);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Stammspieler 1 · Heim 1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Anna'));
    await tester.pumpAndSettle();
    expect(repo.row!['status'], 'pending');
    expect(find.text('Heim 1'), findsOneWidget);
    await repo.respond('invitation', true);
    await tester.scrollUntilVisible(
      find.text('Einladungen aktualisieren'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Einladungen aktualisieren'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Ligaspiel anlegen'));
    await tester.tap(find.text('Ligaspiel anlegen'));
    await tester.pumpAndSettle();
    expect(storage.saved!.players.first.profileId, 'member');
    expect(storage.saved!.leagueMatch!.homePlayers.first, 'Anna');
  });
  testWidgets('recipient must explicitly accept invitation', (tester) async {
    final repo = FakeInvitations();
    await repo.invite('m', 'Heim – Gast', 0, 0, 'user');
    final key = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      LeagueInvitationListener(
        repository: repo,
        navigatorKey: key,
        child: MaterialApp(navigatorKey: key, home: const Scaffold()),
      ),
    );
    await tester.pumpAndSettle();
    expect(repo.row!['status'], 'pending');
    await tester.tap(find.text('Annehmen'));
    await tester.pumpAndSettle();
    expect(repo.row!['status'], 'accepted');
    await tester.pumpWidget(const SizedBox());
  });
}
