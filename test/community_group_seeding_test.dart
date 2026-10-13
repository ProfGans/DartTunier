import 'package:flutter_test/flutter_test.dart';
import 'package:dart_tournament_manager/features/tournaments/domain/engines/community_group_seeding.dart';
import 'package:dart_tournament_manager/features/tournaments/domain/tournament_models.dart';

void main() {
  const seeder = CommunityGroupSeeding();
  final List<TournamentPlayer> players = [
    for (var i = 1; i <= 8; i++)
      TournamentPlayer(
        profileId: 'p$i',
        name: 'Spieler $i',
        isGenerated: false,
      ),
  ];
  final ratings = {for (var i = 1; i <= 8; i++) 'p$i': 2000 - i * 100};

  test('mixed groups alternate the strongest players across groups', () {
    expect(
      seeder.order(
        players: players,
        groupSizes: const [4, 4],
        ratingsByProfileId: ratings,
        mode: CommunityGroupSeedingMode.mixed,
      ),
      [0, 2, 4, 6, 1, 3, 5, 7],
    );
  });

  test('strength split puts the higher ranked half in the first group', () {
    expect(
      seeder.order(
        players: players,
        groupSizes: const [4, 4],
        ratingsByProfileId: ratings,
        mode: CommunityGroupSeedingMode.strengthSplit,
      ),
      [0, 1, 2, 3, 4, 5, 6, 7],
    );
  });

  test('rejects strength split when group count is not two', () {
    expect(
      () => seeder.order(
        players: players,
        groupSizes: const [3, 3, 2],
        ratingsByProfileId: ratings,
        mode: CommunityGroupSeedingMode.strengthSplit,
      ),
      throwsArgumentError,
    );
  });
}
