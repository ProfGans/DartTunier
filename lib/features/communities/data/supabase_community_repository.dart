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
    await _ensureCurrentPlayerProfile();
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
    await _ensureCurrentPlayerProfile();
    final result = await _client.rpc(
      'join_community_by_code',
      params: {'requested_code': inviteCode.trim().toUpperCase()},
    );
    if (result is! Map<String, dynamic>) {
      throw StateError('Community konnte nicht geladen werden.');
    }
    return Community.fromJson(result);
  }

  Future<void> _ensureCurrentPlayerProfile() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw StateError('Fuer Communities ist eine Anmeldung erforderlich.');
    }
    final metadata = user.userMetadata ?? const <String, dynamic>{};
    final displayName =
        (metadata['display_name'] as String?) ?? user.email ?? 'Spieler';
    await _client.from('player_profiles').upsert({
      'id': user.id,
      'user_id': user.id,
      'display_name': displayName.trim(),
      'is_active': true,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<List<CommunityMember>> loadMembers(String communityId) async {
    final rows = await _client
        .from('community_members')
        .select('user_id, role, joined_at, player_profiles(id, display_name)')
        .eq('community_id', communityId)
        .order('joined_at');
    return [
      for (final row in rows)
        CommunityMember(
          userId: row['user_id'] as String,
          playerProfileId:
              (row['player_profiles'] as Map<String, dynamic>?)?['id']
                  as String?,
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
