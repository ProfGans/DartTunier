import 'package:flutter_test/flutter_test.dart';
import 'package:dart_tournament_manager/features/tournaments/domain/engines/qualification_certainty.dart';
import 'package:dart_tournament_manager/features/tournaments/domain/tournament_models.dart';

void main() {
  test('two opponents able to reach 12 prevent a top-two certainty claim', () {
    final players=[for(final i in [8,9,13,10,11]) TournamentPlayer.generated(i)];
    final leader=PlayerStanding(players[0])..points=12..legsFor=8..legsAgainst=4;
    final opponents=[PlayerStanding(players[1])..points=6,PlayerStanding(players[2])..points=6];
    final matches=[for(final opponent in players.skip(1).take(2))
      for(final other in players.skip(3)) GroupMatch(homePlayer:opponent,awayPlayer:other,round:5)];
    bool certain({int points=12,List<String> rules=const ['points','legDifference']}) {
      leader.points=points;
      return const QualificationCertainty().isCertain(standing:leader,place:1,fixedPlaces:2,
        standings:[leader,...opponents],matches:matches,tieBreakers:rules);
    }
    expect(certain(),isFalse);
    expect(certain(points:13),isTrue);
    expect(certain(points:13,rules:['legDifference','points']),isFalse);
    matches.first.isAnnulled=true;
    expect(certain(),isTrue);
    matches.first.isAnnulled=false;
    expect(certain(),isFalse);
  });
}
