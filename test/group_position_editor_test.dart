import 'package:flutter_test/flutter_test.dart';
import 'package:dart_tournament_manager/features/tournaments/domain/engines/group_position_editor.dart';
import 'package:dart_tournament_manager/features/tournaments/domain/tournament_models.dart';

void main() {
  GroupTournamentRunStage fixture() {
    final players = List.generate(6, (i) => TournamentPlayer.generated(i + 1));
    return GroupTournamentRunStage(
      name: 'Gruppen',
      groupPlayType: 'round_robin',
      qualificationPlan: null,
      tieBreakers: [],
      groups: [
        for (var g = 0; g < 2; g++)
          TournamentGroup(
            name: 'Gruppe $g',
            playType: 'round_robin',
            players: players.sublist(g * 3, g * 3 + 3),
            matches: [
              for (var i = 0; i < 3; i++)
                for (var j = i + 1; j < 3; j++)
                  GroupMatch(
                    homePlayer: players[g * 3 + i],
                    awayPlayer: players[g * 3 + j],
                    round: i + j,
                  ),
            ],
          ),
      ],
    );
  }

  test('swaps groups, updates every pairing and survives serialization', () {
    final stage = fixture();
    final a = stage.groups[0].players[0];
    final b = stage.groups[1].players[1];
    expect(GroupPositionEditor.swap(stage, a, b), isTrue);
    for (final group in stage.groups) {
      expect(group.players.length, 3);
      expect(group.matches.length, 3);
      final restored = TournamentGroup.fromJson(group.toJson());
      expect(restored.players, group.players);
      for (final match in restored.matches) {
        expect(restored.players, contains(match.homePlayer));
        expect(restored.players, contains(match.awayPlayer));
        expect(match.homePlayer, isNot(match.awayPlayer));
      }
    }
    expect(stage.groups[0].players[0], b);
    expect(stage.groups[1].players[1], a);
  });

  test('blocks all groups for any started, scored or annulled match', () {
    final blockers = <void Function(GroupMatch)>[
      (m) => m.startedAt = DateTime(2026),
      (m) => m.finishedAt = DateTime(2026),
      (m) => m.homeLegs = 0,
      (m) => m.awaySets = 1,
      (m) => m.isAnnulled = true,
    ];
    for (final block in blockers) {
      final stage = fixture();
      final before = stage.groups.first.players.toList();
      block(stage.groups.last.matches.last);
      expect(GroupPositionEditor.swap(stage, before[0], before[1]), isFalse);
      expect(stage.groups.first.players, before);
    }
  });

  test(
    'mini-KO shared matches and propagated byes are changed exactly once',
    () {
      final stage = fixture();
      final group = stage.groups.first;
      final a = group.players[0];
      final b = group.players[1];
      final bye = GroupMatch(homePlayer: a, round: 1, allowsBye: true);
      final finalMatch = GroupMatch(homePlayer: a, awayPlayer: b, round: 2);
      stage.groups[0] = TournamentGroup(
        name: 'Mini-KO',
        playType: 'mini_knockout',
        players: group.players,
        matches: [bye, finalMatch],
        knockoutRounds: [
          [bye],
          [finalMatch],
        ],
      );
      expect(GroupPositionEditor.swap(stage, a, b), isTrue);
      expect(bye.homePlayer, b);
      expect(finalMatch.homePlayer, b);
      expect(finalMatch.awayPlayer, a);
      expect(bye.awayPlayer, isNull);
    },
  );
}
