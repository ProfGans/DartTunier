import 'package:flutter_test/flutter_test.dart';
import 'package:dart_tournament_manager/features/communities/application/community_live_ranking.dart';
import 'package:dart_tournament_manager/features/communities/application/community_tournament_elo.dart';
import 'package:dart_tournament_manager/features/communities/domain/community_elo.dart';
import 'package:dart_tournament_manager/features/tournaments/domain/tournament_models.dart';
import 'community_tournament_elo_test.dart' show eloTournament, eloMembers;

void main() {
  test('yearly Elo is unchanged after UTC serialization at New Year', () {
    final tournament = eloTournament(completed: true);
    final restored = CreatedTournament.fromJson(tournament.toJson());
    CommunityEloSnapshot calculate(CreatedTournament t) =>
        const CommunityEloCalculator().calculate(
          members: eloMembers,
          tournaments: [t],
          currentYearOnly: true,
          now: DateTime(2026, 6),
        );
    expect(
      calculate(restored).entries.map((e) => e.rating),
      calculate(tournament).entries.map((e) => e.rating),
    );
    expect(calculate(restored).entries, hasLength(2));
  });
  for (final score in [(3, 1), (1, 3), (2, 2)]) {
    test('preview matches chronological live Elo for result $score', () {
      final t = eloTournament();
      final games =
          (t.runStages.first as GroupTournamentRunStage).groups.first.matches;
      // A later scheduled match finishes first on another board.
      games.last.homeLegs = 3;
      games.last.awayLegs = 1;
      games.last.finishedAt = DateTime(2026, 1, 2);
      final before = const CommunityTournamentElo()
          .calculate(
            tournament: t,
            tournaments: [],
            members: eloMembers,
            rankingId: 'default',
            currentYearOnly: false,
            activeStage: 0,
          )
          .first;
      expect(before.rating, 1016);
      final expected =
          before.rating! +
          (score.$1 == score.$2
              ? before.draw!
              : score.$1 > score.$2
              ? before.win!
              : before.loss!);
      games.first.homeLegs = score.$1;
      games.first.awayLegs = score.$2;
      games.first.finishedAt = DateTime(2026, 1, 3);
      final saved = CreatedTournament.fromJson(t.toJson());
      final snapshot = const CommunityEloCalculator().calculate(
        members: eloMembers,
        tournaments: [saved, saved],
        currentYearOnly: false,
      );
      final home = snapshot.entries.singleWhere(
        (e) => e.player.playerProfileId == 'a',
      );
      expect(home.rating, expected);
      expect(home.matches, 2);
      expect(snapshot.entries.fold<int>(0, (sum, e) => sum + e.rating), 2000);
      expect(snapshot.history['a']!.map((e) => e.playedAt.toLocal()), [
        DateTime(2026, 1, 2),
        DateTime(2026, 1, 3),
      ]);
      final live = const CommunityLiveRanking().calculate(
        tournament: t,
        tournaments: [saved],
        members: eloMembers,
        rankingId: 'default',
        currentYearOnly: false,
      );
      expect(
        live
            .singleWhere((e) => e.entry.player.playerProfileId == 'a')
            .entry
            .rating,
        expected,
      );
      // Correcting/removing a result must recompute instead of adding a delta again.
      games.first.homeLegs = null;
      games.first.awayLegs = null;
      expect(
        const CommunityEloCalculator()
            .calculate(
              members: eloMembers,
              tournaments: [t],
              currentYearOnly: false,
            )
            .entries
            .singleWhere((e) => e.player.playerProfileId == 'a')
            .rating,
        1016,
      );
    });
  }
}
