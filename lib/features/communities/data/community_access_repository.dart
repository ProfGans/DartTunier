import 'package:supabase_flutter/supabase_flutter.dart';
import '../../tournaments/data/tournament_storage.dart';
import '../domain/community_permissions.dart';

class CommunityAccessRepository {
  CommunityAccessRepository({
    SupabaseClient? client,
    TournamentStorage? storage,
  }) : _clientOverride = client,
       _storage = storage ?? TournamentStorage();
  final SupabaseClient? _clientOverride;
  final TournamentStorage _storage;
  SupabaseClient get client => _clientOverride ?? Supabase.instance.client;

  Future<CommunityPermissions> permissions(String communityId) async {
    final user = client.auth.currentUser?.id;
    if (user == null) return CommunityPermissions([]);
    final cacheKey = 'community-access-v1:$user:$communityId';
    List<dynamic> keys;
    try {
      keys = List<dynamic>.from(
        await client
                .rpc(
                  'community_permissions',
                  params: {'requested_community_id': communityId},
                )
                .timeout(const Duration(seconds: 5))
            as List,
      );
    } on PostgrestException {
      // Missing migrations or rejected authentication must never restore old grants.
      rethrow;
    } catch (_) {
      if (client.auth.currentUser?.id != user) return CommunityPermissions([]);
      return CommunityPermissions(
        (await _storage.readCache(cacheKey) ?? []).cast<String>(),
      );
    }
    if (client.auth.currentUser?.id != user) return CommunityPermissions([]);
    await _storage.writeCache(cacheKey, keys);
    return CommunityPermissions(keys.cast<String>());
  }

  Future<void> require(
    String? communityId,
    CommunityPermission permission,
  ) async {
    if (communityId == null) return;
    if (!(await permissions(communityId)).allows(permission)) {
      throw StateError('Keine Berechtigung: ${permission.label}');
    }
  }

  Future<void> requireCached(
    String communityId,
    CommunityPermission permission,
  ) async {
    final user = client.auth.currentUser?.id;
    final keys = user == null
        ? <dynamic>[]
        : await _storage.readCache('community-access-v1:$user:$communityId') ??
              [];
    if (!keys.contains(permission.key)) {
      throw StateError(
        'Keine Berechtigung: ${permission.label}. Rechte zuerst online laden.',
      );
    }
  }

  Future<List<CommunityRole>> roles(String id) async => [
    for (final row
        in await client
            .from('community_roles')
            .select()
            .eq('community_id', id)
            .order('name'))
      CommunityRole.fromJson(row),
  ];
  Future<Map<String, String>> assignments(String id) async => {
    for (final row
        in await client
            .from('community_role_assignments')
            .select('user_id,role_id')
            .eq('community_id', id))
      row['user_id'] as String: row['role_id'] as String,
  };
  Future<void> saveRole(
    String communityId,
    String name,
    Iterable<String> permissions, {
    String? id,
  }) async {
    final row = {
      'community_id': communityId,
      'name': name.trim(),
      'permissions': permissions.toList(),
    };
    if (id == null) {
      await client.from('community_roles').insert(row);
    } else {
      await client
          .from('community_roles')
          .update(row)
          .eq('community_id', communityId)
          .eq('id', id)
          .select('id')
          .single();
    }
  }

  Future<void> assign(String communityId, String userId, String? roleId) async {
    await client.rpc(
      'assign_community_role',
      params: {
        'requested_community_id': communityId,
        'target_user_id': userId,
        'requested_role_id': roleId,
      },
    );
  }

  Future<void> removeMember(String communityId, String userId) async {
    await client.rpc(
      'remove_community_member',
      params: {'requested_community_id': communityId, 'target_user_id': userId},
    );
  }

  Future<void> removeManualMember(String communityId, String memberId) async {
    await client
        .from('community_guest_members')
        .delete()
        .eq('community_id', communityId)
        .eq('id', memberId)
        .select('id')
        .single();
  }

  Future<String> invitation(String communityId) async =>
      await client.rpc(
            'community_invitation',
            params: {'requested_community_id': communityId},
          )
          as String;
}
