import 'package:supabase_flutter/supabase_flutter.dart';
import '../../tournaments/domain/tournament_models.dart';

class LeagueResultRepository {
  Future<CreatedTournament> submit(
    CreatedTournament tournament,
    int index,
    int home,
    int away,
  ) async {
    final league = tournament.leagueMatch!;
    if (league.games[index].complete) {
      throw StateError('Korrekturen bleiben der Turnierleitung vorbehalten.');
    }
    final metadata = league.toJson()..remove('games');
    final result = await Supabase.instance.client.rpc(
      'submit_league_result',
      params: {
        'target_tournament': tournament.id,
        'game_index': index,
        'expected_game': league.games[index].toJson(),
        'expected_metadata': metadata,
        'home_score': home,
        'away_score': away,
      },
    );
    return CreatedTournament.fromJson(Map<String, dynamic>.from(result as Map));
  }
}
