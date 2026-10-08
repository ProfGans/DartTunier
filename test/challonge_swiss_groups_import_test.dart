import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_tournament_manager/features/communities/data/challonge_public_reader.dart';
import 'package:dart_tournament_manager/features/communities/application/challonge_native_import.dart';
import 'package:dart_tournament_manager/features/tournaments/domain/tournament_models.dart';

// Public DCUH202601 data observed 2026-10-08; account and image metadata omitted.
void main() {
  test(
    'DCUH202601 imports five Swiss rounds, five byes and the final from standings link',
    () async {
      const names = [
        'Friedel_D',
        'KKKEVIN_Tsrik',
        'Marvin_S',
        'Markus_D',
        'Paddi_Kaspar',
        'Steve_T',
        'Timo_S',
        'Jonas_B',
        'Mike_Ro',
        'Max_Re',
        'Dietmar_S',
        'robin_ha',
        'Tobi_Be',
      ];
      const ids = [
        41390999,
        41391000,
        41391001,
        41391010,
        41391003,
        41391004,
        41391005,
        41391006,
        41391007,
        41391008,
        41391009,
        41391011,
        41391002,
      ];
      const games = [
        [1, 1, 7, 2, 0],
        [1, 2, 8, 0, 2],
        [1, 3, 9, 2, 1],
        [1, 4, 10, 0, 2],
        [1, 5, 11, 2, 0],
        [1, 6, 12, 2, 0],
        [2, 11, 7, 0, 2],
        [2, 9, 4, 1, 2],
        [2, 2, 13, 1, 2],
        [2, 1, 8, 2, 0],
        [2, 3, 10, 0, 2],
        [2, 5, 6, 0, 2],
        [3, 1, 10, 2, 0],
        [3, 6, 13, 2, 1],
        [3, 9, 2, 1, 2],
        [3, 3, 7, 2, 1],
        [3, 4, 8, 0, 2],
        [3, 5, 12, 2, 0],
        [4, 1, 6, 1, 2],
        [4, 12, 7, 2, 1],
        [4, 11, 4, 1, 2],
        [4, 2, 5, 2, 1],
        [4, 10, 8, 2, 0],
        [4, 3, 13, 0, 2],
        [5, 6, 10, 2, 0],
        [5, 1, 13, 0, 2],
        [5, 11, 9, 0, 2],
        [5, 8, 5, 1, 2],
        [5, 2, 4, 2, 1],
        [5, 3, 12, 0, 2],
      ];
      Map<String, dynamic> match(
        int id,
        List<int> g, {
        bool finalMatch = false,
      }) {
        int pid(int seed) =>
            finalMatch ? (seed == 6 ? 282408763 : 282408777) : ids[seed - 1];
        return {
          'id': id,
          'round': g[0],
          'state': 'complete',
          'games': [
            [g[3], g[4]],
          ],
          'player1': {
            'id': pid(g[1]),
            'display_name': names[g[1] - 1],
            'seed': g[1],
          },
          'player2': {
            'id': pid(g[2]),
            'display_name': names[g[2] - 1],
            'seed': g[2],
          },
          'winner_id': pid(g[g[3] > g[4] ? 1 : 2]),
          'loser_id': pid(g[g[3] > g[4] ? 2 : 1]),
        };
      }

      const bases = [440936041, 440937282, 440940473, 440943294, 440947506];
      const rankSeeds = [6, 13, 1, 5, 2, 10, 12, 3, 8, 4, 9, 7, 11];
      final store = {
        'tournament': {
          'id': 17334574,
          'state': 'complete',
          'tournament_type': 'single elimination',
          'participants_per_match': 2,
          'is_team': false,
          'split_participants': false,
        },
        'matches_by_round': {
          '1': [
            match(440952971, [1, 6, 13, 2, 1], finalMatch: true),
          ],
        },
        'groups': [
          {
            'name': 'Gruppe A',
            'tournament': {'tournament_type': 'swiss', 'state': 'complete'},
            'matches_by_round': {
              for (var r = 1; r <= 5; r++)
                '$r': [
                  for (final e in games.indexed.where((e) => e.$2[0] == r))
                    match(bases[r - 1] + e.$1 % 6, e.$2),
                ],
            },
            'scorecard_html':
                '<table><tbody>${rankSeeds.indexed.map((e) => '<tr><td>${e.$1 + 1}</td><td class="participant"><a>${names[e.$2 - 1]}</a></td></tr>').join()}</tbody></table>',
          },
        ],
      };
      final source =
          '<meta property="og:title" content="Vereinsheim Unzenberg 2026 - 1. Spieltag - Challonge"><div class="start-time">January 5, 2026 bei 4:00 PM CET</div><a href="/de/DCUH202601/standings">Platzierungen</a><script>window._initialStoreState[\'TournamentStore\'] = ${jsonEncode(store)};</script>';
      const standings =
          '<table class="standings"><tr><td class="rank">1</td><td class="display_name">Steve_T</td></tr><tr><td class="rank">2</td><td class="display_name">Tobi_Be</td></tr></table>';
      final visited = <String>[];
      final reader = ChallongePublicReader(
        readDocument: (uri) async {
          visited.add(uri.path);
          return uri.path.endsWith('standings') ? standings : source;
        },
      );
      final parsed = await reader.tournament(
        'https://challonge.com/de/DCUH202601/standings',
      );
      expect(visited, ['/de/DCUH202601', '/de/DCUH202601/standings']);
      expect(parsed.participants, hasLength(13));
      expect(parsed.matches, hasLength(31));
      final native = ChallongeNativeImport.convert(
        parsed.convert('club', {
          for (final p in parsed.participants)
            '${p['id']}': 'member-${p['id']}',
        }),
      );
      final groups = native.runStages.first as GroupTournamentRunStage;
      expect(groups.groups.single.playType, 'swiss');
      expect(native.stages.first.groupPlayTypes, ['swiss']);
      expect(native.stages.first.groupRoundRobinRepeats, [5]);
      expect(
        groups.groups.single.matches.where((m) => m.hasResult),
        hasLength(30),
      );
      expect(
        groups.groups.single.matches.where((m) => m.allowsBye),
        hasLength(5),
      );
      expect(groups.qualificationPlan!.totalQualifiers, 2);
      final finalStage = native.runStages.last as KnockoutTournamentRunStage;
      expect(finalStage.rounds.single.single.winner!.name, 'Steve_T');
      expect(finalStage.rounds.single.single.awayLegs, 1);
      expect(native.importedArchive!.matches, hasLength(31));
      expect(native.importedArchive!.usesNativeLogic, isTrue);
    },
  );
}
