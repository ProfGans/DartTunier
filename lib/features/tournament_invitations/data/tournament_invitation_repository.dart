import 'package:supabase_flutter/supabase_flutter.dart';
import '../../tournaments/domain/tournament_models.dart';

class TournamentInvitationRepository {
  TournamentInvitationRepository({SupabaseClient? client})
    : client = client ?? Supabase.instance.client;
  final SupabaseClient client;
  Future<String> create(CreatedTournament t) async =>
      await client.rpc(
            'create_tournament_invitation',
            params: {
              'target_id': t.id,
              'tournament_title': t.name,
              'target_community': t.communityId,
            },
          )
          as String;
  Future<Map<String, dynamic>?> info(String token) async {
    final data = await client.rpc(
      'tournament_invitation_info',
      params: {'invitation_token': token},
    );
    return data == null ? null : Map<String, dynamic>.from(data as Map);
  }

  Future<void> join(String token, String name, String requestId) async {
    await client.rpc(
      'request_tournament_join',
      params: {
        'invitation_token': token,
        'player_name': name,
        'request_key': requestId,
      },
    );
  }

  Future<List<Map<String, dynamic>>> requests(String token) async =>
      List<Map<String, dynamic>>.from(
        await client
            .from('tournament_join_requests')
            .select()
            .eq('invitation_id', token)
            .eq('status', 'pending')
            .order('created_at'),
      );
  Future<void> resolve(
    String id, {
    required bool accept,
    String? playerKey,
    bool community = false,
  }) async {
    await client.rpc(
      'resolve_tournament_join',
      params: {
        'request_id': id,
        'accept': accept,
        'target_player_key': playerKey,
        'add_to_community': community,
      },
    );
  }
}
