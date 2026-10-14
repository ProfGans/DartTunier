import 'package:dart_tournament_manager/features/statistics/domain/best_performance.dart';
import 'package:dart_tournament_manager/features/tournaments/domain/tournament_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('match best performances survive local tournament JSON roundtrip', () {
    final match = GroupMatch(
      homePlayer: TournamentPlayer(profileId: 'player-1', name: 'Spieler 1', isGenerated: false),
      awayPlayer: TournamentPlayer(profileId: 'player-2', name: 'Spieler 2', isGenerated: false),
      round: 1,
      homeLegs: 2,
      awayLegs: 0,
      bestPerformances: const [
        BestPerformance(
          type: BestPerformanceType.score180,
          playerName: 'Spieler 1',
          playerProfileId: 'player-1',
        ),
        BestPerformance(
          type: BestPerformanceType.highFinish,
          playerName: 'Spieler 2',
          playerProfileId: 'player-2',
          value: 120,
        ),
      ],
    );

    final restored = GroupMatch.fromJson(match.toJson());

    expect(restored.bestPerformances, hasLength(2));
    expect(restored.bestPerformances.first.type, BestPerformanceType.score180);
    expect(restored.bestPerformances.last.playerProfileId, 'player-2');
    expect(restored.bestPerformances.last.value, 120);
  });
}
