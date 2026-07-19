import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../tournaments/domain/tournament_models.dart';
import '../domain/community.dart';

class SupabaseCommunityRepository {
  SupabaseCommunityRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  String get currentUserId {
    final id = _client.auth.currentUser?.id;
    if (id == null) {
      throw StateError('Fuer Communities ist eine Anmeldung erforderlich.');
    }
    return id;
  }

  Future<List<Community>> loadMyCommunities() async {
    final rows = await _client
        .from('community_members')
        .select('communities(*)')
        .eq('user_id', currentUserId);
    return [
      for (final row in rows)
        if (row['communities'] case final Map<String, dynamic> community)
          Community.fromJson(community),
    ]..sort((a, b) => a.name.compareTo(b.name));
  }

  Future<Community> createCommunity({
    required String name,
    required String description,
  }) async {
    final userId = currentUserId;
    final inserted = await _client
        .from('communities')
        .insert({
          'owner_user_id': userId,
          'name': name.trim(),
          'description': description.trim(),
          'invite_code': _createInviteCode(),
        })
        .select()
        .single();
    await _client.from('community_members').insert({
      'community_id': inserted['id'],
      'user_id': userId,
      'role': 'owner',
    });
    return Community.fromJson(inserted);
  }

  Future<Community> joinCommunity(String inviteCode) async {
    final result = await _client.rpc(
      'join_community_by_code',
      params: {'requested_code': inviteCode.trim().toUpperCase()},
    );
    if (result is! Map<String, dynamic>) {
      throw StateError('Community konnte nicht geladen werden.');
    }
    return Community.fromJson(result);
  }

  Future<List<CommunityMember>> loadMembers(String communityId) async {
    final rows = await _client
        .from('community_members')
        .select('user_id, role, joined_at, player_profiles(display_name)')
        .eq('community_id', communityId)
        .order('joined_at');
    return [
      for (final row in rows)
        CommunityMember(
          userId: row['user_id'] as String,
          displayName:
              (row['player_profiles'] as Map<String, dynamic>?)?['display_name']
                  as String? ??
              'Mitglied',
          role: row['role'] as String? ?? 'member',
          joinedAt:
              DateTime.tryParse(row['joined_at'] as String? ?? '') ??
              DateTime.fromMillisecondsSinceEpoch(0),
        ),
    ];
  }

  Future<List<CreatedTournament>> loadTournaments(String communityId) async {
    final rows = await _client
        .from('tournaments')
        .select('payload')
        .eq('community_id', communityId)
        .eq('is_deleted', false)
        .order('updated_at', ascending: false);
    return [
      for (final row in rows)
        if (row['payload'] case final Map<String, dynamic> payload)
          CreatedTournament.fromJson(payload),
    ];
  }

  String _createInviteCode() {
    const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random.secure();
    return List.generate(
      8,
      (_) => alphabet[random.nextInt(alphabet.length)],
    ).join();
  }
}
