import 'package:flutter_test/flutter_test.dart';
import 'package:dart_tournament_manager/features/communities/data/challonge_public_document.dart';

void main() {
  // The participant cell on DCUH202629 includes the tournament label Tom_Dc
  // and the separate account name Tom_Ba in parentheses.
  test(
    'custom tournament name and account name remain separate in both rankings',
    () {
      const cell = '''<span class="label label-info">Erweitert</span>
<img class="portrait" alt="" />
Tom_Dc
(<a class="link-text -primary" href="https://challonge.com/de/users/tom_ba">Tom_Ba</a>)''';
      final store = fixture(
        '<table><tbody><tr><td>1</td><td class="participant">$cell</td></tr></tbody></table>',
      );
      final result = ChallongePublicDocument.convert(
        source,
        '<table class="standings"><tbody><tr><td class="rank">1</td><td class="display_name">$cell</td></tr></tbody></table>',
        store,
        Uri.parse('https://challonge.com/de/DCUH202629'),
      );
      final player = result.participants.singleWhere(
        (p) => p['name'] == 'Tom_Dc',
      );
      expect(player['final_rank'], 1);
      expect(player['group_placements'], [
        {'group': 'Gruppe A', 'rank': 1},
      ]);
      expect(result.participants.any((p) => p['name'] == 'Tom_Ba'), isFalse);
    },
  );
  test('changed row label is identified only by unambiguous match history', () {
    final result = ChallongePublicDocument.convert(
      source,
      standings,
      fixture(
        '<table><tbody><tr><td>1</td><td class="participant">Abweichende Anzeige</td><td><a data-match-id="10"></a><a data-match-id="11"></a></td></tr></tbody></table>',
      ),
      Uri.parse('https://challonge.com/de/DCUH202629'),
    );
    expect(result.participants.first['group_placements'], [
      {'group': 'Gruppe A', 'rank': 1},
    ]);
  });
  test('ambiguous match history is rejected with tournament and participant', () {
    expect(
      () => ChallongePublicDocument.convert(
        source,
        standings,
        fixture(
          '<table><tbody><tr><td>1</td><td class="participant">Unbekannt</td><td><a data-match-id="10"></a></td></tr></tbody></table>',
        ),
        Uri.parse('https://challonge.com/de/DCUH202629'),
      ),
      throwsA(
        isA<FormatException>().having(
          (e) => e.message,
          'detail',
          allOf(contains('Unbekannt'), contains('DCUH202629')),
        ),
      ),
    );
  });
}

const source =
    '<meta property="og:title" content="Spieltag 29 - Challonge"><div class="start-time">August 5, 2026 bei 8:30 AM CEST</div>';
const standings =
    '<table class="standings"><tbody><tr><td class="rank">1</td><td class="display_name">Tom_Dc</td></tr></tbody></table>';
Map<String, dynamic> fixture(String scorecard) => {
  'tournament': {
    'id': 29,
    'state': 'complete',
    'is_team': false,
    'split_participants': false,
    'participants_per_match': 2,
    'tournament_type': 'round robin',
  },
  'matches_by_round': {},
  'groups': [
    {
      'name': 'Gruppe A',
      'scorecard_html': scorecard,
      'matches_by_round': {
        '1': [
          {
            'id': 10,
            'state': 'complete',
            'player1': {'id': 1, 'display_name': 'Tom_Dc'},
            'player2': {'id': 2, 'display_name': 'Jan'},
            'games': [
              [2, 0],
            ],
            'winner_id': 1,
            'loser_id': 2,
          },
          {
            'id': 11,
            'state': 'complete',
            'player1': {'id': 1, 'display_name': 'Tom_Dc'},
            'player2': {'id': 3, 'display_name': 'Mike'},
            'games': [
              [2, 1],
            ],
            'winner_id': 1,
            'loser_id': 3,
          },
        ],
      },
    },
  ],
};
