import 'package:supabase_flutter/supabase_flutter.dart';
import '../../tournaments/data/tournament_storage.dart';
import '../domain/community_permissions.dart';
import '../domain/community_ranking_action.dart';
import 'community_access_repository.dart';

class CommunityRankingAdminRepository {
  CommunityRankingAdminRepository(this.client, {TournamentStorage? storage})
    : storage = storage ?? TournamentStorage();
  final SupabaseClient client;
  final TournamentStorage storage;

  String get _user =>
      client.auth.currentUser?.id ??
      (throw StateError('Anmeldung erforderlich'));
  String _key(String user, String community) =>
      'ranking-actions-v1:$user:$community';

  Future<List<CommunityRankingAction>> load(String community) async {
    final user = _user;
    List<dynamic> rows;
    try {
      rows = await client
          .from('community_ranking_actions')
          .select()
          .eq('community_id', community)
          .order('id')
          .timeout(const Duration(seconds: 5));
    } on PostgrestException {
      rethrow;
    } catch (_) {
      if (_user != user) rethrow;
      final cache = await storage.readCache(_key(user, community));
      if (cache == null) rethrow;
      rows = cache;
    }
    if (_user != user) throw StateError('Account gewechselt');
    await storage.writeCache(_key(user, community), rows);
    return [
      for (final row in rows)
        CommunityRankingAction.fromJson(Map<String, dynamic>.from(row as Map)),
    ];
  }

  Future<CommunityRankingAction> apply(
    String community,
    String ranking,
    String player,
    RankingPlayerAction action,
  ) async {
    final user = _user;
    await CommunityAccessRepository(
      client: client,
    ).require(community, CommunityPermission.manageRankings);
    final row = Map<String, dynamic>.from(
      await client.rpc(
            'manage_ranking_player',
            params: {
              'requested_community_id': community,
              'requested_ranking_id': ranking,
              'requested_player_key': player,
              'requested_action': action.name,
            },
          )
          as Map,
    );
    if (_user != user) throw StateError('Account gewechselt');
    try {
      final key = _key(user, community);
      final cache = await storage.readCache(key);
      if (cache != null) await storage.writeCache(key, [...cache, row]);
    } catch (_) {
      // The server has already accepted this action.
    }
    return CommunityRankingAction.fromJson(row);
  }
}
