import 'package:dart_tournament_manager/features/tournaments/domain/tournament_models.dart';

GroupMatch recordedMatch() =>
    GroupMatch(
        homePlayer: const TournamentPlayer(
          name: 'Anna Musterfrau',
          profileId: 'a',
          isGenerated: false,
        ),
        awayPlayer: const TournamentPlayer(
          name: 'Ben Beispielmann',
          profileId: 'b',
          isGenerated: false,
        ),
        round: 1,
      )
      ..homeLegs = 1
      ..awayLegs = 0;
