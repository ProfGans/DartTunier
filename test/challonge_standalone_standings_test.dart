import 'package:flutter_test/flutter_test.dart';
import 'package:dart_tournament_manager/features/communities/data/challonge_public_document.dart';

void main() {
  for (final mode in ['swiss', 'round robin']) {
    test('$mode uses the published participant table, including tied ranks', () {
      final players = [
        {'id': 1, 'display_name': 'Friedel_D'},
        {'id': 2, 'display_name': 'Kevin_noXSSXon'},
        {'id': 3, 'display_name': 'Mike_Ro'},
      ];
      final store = {
        'tournament': {
          'id': 2,
          'state': 'complete',
          'tournament_type': mode,
          'is_team': false,
          'split_participants': false,
          'participants_per_match': 2,
        },
        'groups': [],
        'matches_by_round': {
          '1': [
            {
              'id': 10,
              'state': 'complete',
              'player1': players[0],
              'player2': players[1],
              'games': [
                [2, 0],
              ],
              'winner_id': 1,
              'loser_id': 2,
            },
            {
              'id': 11,
              'state': 'complete',
              'player1': players[0],
              'player2': players[2],
              'games': [
                [2, 0],
              ],
              'winner_id': 1,
              'loser_id': 3,
            },
          ],
        },
      };
      // DCUH202602 uses td.participant and an unclassified first rank cell.
      const standings =
          '''<table class="striped-table -light limited_width standings"><tbody>
<tr><td class="text-center">1</td><td class="participant"><img class="portrait"/><a href="/de/users/friedel_d">Friedel_D</a></td></tr>
<tr><td class="text-center">2</td><td class="participant">Kevin_noXSSXon (<a href="/de/users/kkkevin_tsrik">KKKEVIN_Tsrik</a>)</td></tr>
<tr><td class="text-center">2</td><td class="participant">Mike_Ro</td></tr>
</tbody></table>''';
      final result = ChallongePublicDocument.convert(
        '<meta property="og:title" content="Spieltag 2 - Challonge"><div class="start-time">January 14, 2026 bei 12:52 PM CET</div>',
        standings,
        store,
        Uri.parse('https://challonge.com/de/DCUH202602'),
      );
      expect(result.participants.map((p) => p['final_rank']), [1, 2, 2]);
      expect(result.matches.length, 2);
    });
  }
}
