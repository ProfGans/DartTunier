import 'package:flutter_test/flutter_test.dart';
import 'package:dart_tournament_manager/features/tournaments/domain/tournament_models.dart';
import 'package:dart_tournament_manager/features/scorer/domain/scorer_settings.dart';
import 'package:dart_tournament_manager/features/scorer/application/scorer_controller.dart';
import 'package:dart_tournament_manager/features/devices/domain/board_display.dart';
import 'package:dart_tournament_manager/features/devices/application/device_scorer_settings.dart';

void main() {
  test('team merge flattens rosters and survives storage round trip', () {
    const a = TournamentPlayer(name: 'A', profileId: 'a', isGenerated: false);
    final b = TournamentPlayer.generated(2);
    final team = TournamentPlayer.team([
      TournamentPlayer.team([a, b]),
      TournamentPlayer.generated(3),
    ]);
    final restored = TournamentPlayer.fromJson(team.toJson());
    expect(restored, team);
    expect(restored.individuals.length, 3);
    expect(restored.individuals.first.profileId, 'a');
    expect(restored.copyWith(name: 'Team').members, team.members);
    expect(
      () => TournamentPlayer.team([a, a.copyWith(name: 'Alias')]),
      throwsArgumentError,
    );
    expect(TournamentPlayer.fromJson(b.toJson()).isTeam, isFalse);
  });
  test(
    'teams rotate after visits, busts and checkouts; undo restores thrower',
    () {
      final c = ScorerController(
        ScorerSettings(
          startScore: 40,
          participants: const [
            ScorerParticipant('Doppel', members: ['A', 'B']),
            ScorerParticipant('Triple', members: ['C', 'D', 'E']),
          ],
        ),
      );
      expect(c.activeThrower, 'A');
      c.submitBust();
      expect(c.activeThrower, 'C');
      c.submitBust();
      expect(c.activeThrower, 'B');
      c.submitScore(40, checkoutDarts: 1, checkoutAttempts: 1);
      expect(c.legs, [1, 0]);
      expect(c.activeThrower, 'D');
      c.undo();
      expect(c.activeThrower, 'B');
      expect(c.legs, [0, 0]);
      c.submitScore(20);
      expect(c.scores, [20, 40]);
      c.submitBust();
      expect(c.activeThrower, 'A');
    },
  );
  test(
    'device payload retains team roster and produces team scorer settings',
    () {
      const display = BoardDisplay(
        tournamentId: '1',
        tournamentName: 'T',
        board: 1,
        state: 'running',
        home: 'Team A',
        away: 'Team B',
        homeMembers: ['A', 'B'],
        awayMembers: ['C', 'D', 'E', 'F'],
        gameFormat: TournamentGameFormat(),
      );
      final settings = deviceScorerSettings(
        BoardDisplay.fromJson(display.toJson()),
      );
      expect(settings.participants.first.members, ['A', 'B']);
      expect(settings.participants.last.members.length, 4);
    },
  );
}
