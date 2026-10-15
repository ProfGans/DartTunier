import 'package:flutter_test/flutter_test.dart';
import 'package:dart_tournament_manager/features/challonge/domain/challonge_tournament.dart';

void main() {
  test('convert allows multiple unlinked players when allowUnlinkedPlayers is true', () {
    final fixture = {
      'id': 12345,
      'name': 'Test Challonge',
      'state': 'complete',
      'created_at': '2026-01-01T10:00:00Z',
      'completed_at': '2026-01-01T14:00:00Z',
      'participants': [
        {'id': 1, 'name': 'Player 1', 'final_rank': 1},
        {'id': 2, 'name': 'Player 2', 'final_rank': 2},
        {'id': 3, 'name': 'Player 3', 'final_rank': 3},
        {'id': 4, 'name': 'Player 4', 'final_rank': 4},
      ],
      'matches': [
        {
          'id': 101,
          'state': 'complete',
          'round': 1,
          'player1_id': 1,
          'player2_id': 2,
          'scores_csv': '3-1',
          'winner_id': 1,
          'loser_id': 2,
        },
      ],
    };

    final tournament = ChallongeTournament(fixture);

    // Only player 1 is linked to 'profile_p1', players 2, 3, 4 are unlinked.
    final profiles = <String, String>{
      '1': 'profile_p1',
    };

    final converted = tournament.convert(
      profiles,
      allowUnlinkedPlayers: true,
    );

    expect(converted.name, 'Test Challonge');
    expect(converted.players.length, 4);
    expect(converted.players.firstWhere((p) => p.name == 'Player 1').profileId, 'profile_p1');
    expect(converted.players.firstWhere((p) => p.name == 'Player 2').profileId, isNull);
    expect(converted.players.firstWhere((p) => p.name == 'Player 3').profileId, isNull);
    expect(converted.players.firstWhere((p) => p.name == 'Player 4').profileId, isNull);
  });

  test('convert rejects assigning the same profileId to two different participants', () {
    final fixture = {
      'id': 12346,
      'name': 'Test Duplicate',
      'state': 'complete',
      'created_at': '2026-01-01T10:00:00Z',
      'completed_at': '2026-01-01T14:00:00Z',
      'participants': [
        {'id': 1, 'name': 'Player 1', 'final_rank': 1},
        {'id': 2, 'name': 'Player 2', 'final_rank': 2},
      ],
      'matches': [
        {
          'id': 101,
          'state': 'complete',
          'round': 1,
          'player1_id': 1,
          'player2_id': 2,
          'scores_csv': '3-1',
          'winner_id': 1,
          'loser_id': 2,
        },
      ],
    };

    final tournament = ChallongeTournament(fixture);

    // Both players assigned to same profile
    final profiles = <String, String>{
      '1': 'profile_same',
      '2': 'profile_same',
    };

    expect(
      () => tournament.convert(profiles, allowUnlinkedPlayers: true),
      throwsA(isA<ArgumentError>()),
    );
  });
}
