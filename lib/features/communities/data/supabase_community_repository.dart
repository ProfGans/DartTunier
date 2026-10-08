import 'dart:math';
import '../../personal_profile/domain/personal_profile.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../tournaments/domain/tournament_models.dart';
import '../../tournaments/data/tournament_storage.dart';
import '../domain/community.dart';
import '../domain/community_ranking.dart';
import 'community_access_repository.dart';
import 'community_ranking_admin_repository.dart';
import '../domain/community_ranking_action.dart';
import '../domain/community_permissions.dart';

class SupabaseCommunityRepository {
  SupabaseCommunityRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;
  Future<PersonalProfile?> loadAccountProfile(String communityId, String userId) async {
    final viewer = currentUserId;
    final result = await _client.rpc('community_account_profile', params: {
      'requested_community_id': communityId,
      'target_user_id': userId,
    });
    if (viewer != currentUserId) throw StateError('Account wurde gewechselt.');
    return result == null ? null : PersonalProfile.fromJson(Map<String, dynamic>.from(result as Map));
  }
  final TournamentStorage _storage = TournamentStorage();
  Future<List<CommunityRankingAction>> loadRankingActions(String communityId) =>
    CommunityRankingAdminRepository(_client, storage: _storage).load(communityId);
  Future<CommunityRankingAction> manageRankingPlayer(String communityId,
      String rankingId, String playerKey, RankingPlayerAction action) =>
    CommunityRankingAdminRepository(_client, storage: _storage)
      .apply(communityId, rankingId, playerKey, action);
  CommunityAccessRepository get access =>
      CommunityAccessRepository(client: _client);
  static const communityColumns =
      'id,owner_user_id,name,description,avatar_base64,ranking_enabled,created_at,updated_at';

  Future<Community> updateProfile(
    Community community, {
    required String name,
    required String bio,
    required String? avatarBase64,
    bool? rankingEnabled,
  }) async {
    final accountId = currentUserId;
    await access.require(community.id, CommunityPermission.editCommunity);
    if (name.trim().isEmpty ||
        name.trim().length > 80 ||
        bio.trim().length > 1000 ||
        (avatarBase64?.length ?? 0) > 131072) {
      throw const FormatException('Name, Bio oder Profilbild ist ungültig.');
    }
    final row = Map<String, dynamic>.from(
      await _client.rpc(
            'update_community_settings',
            params: {
              'requested_community_id': community.id,
              'profile_name': name.trim(),
              'profile_bio': bio.trim(),
              'profile_avatar': avatarBase64,
              'enable_ranking': rankingEnabled ?? community.rankingEnabled,
            },
          )
          as Map,
    );
    if (currentUserId != accountId) {
      throw StateError('Account wurde gewechselt.');
    }
    try {
      final cached = await _storage.readCache('communities');
      if (cached != null) {
        await _storage.writeCache('communities', [
          for (final item in cached)
            if ((item as Map)['communities'] is Map &&
                (item['communities'] as Map)['id'] == community.id)
              {'communities': row}
            else
              item,
        ]);
      }
    } catch (_) {
      // The server already saved successfully; a cache failure must not report an unsaved profile.
    }
    return Community.fromJson(row);
  }

  Future<List<dynamic>> _cachedRows(
    String key,
    Future<List<dynamic>> Function() fetch, {
    List<dynamic>? emptyCacheFallback,
  }) async {
    final userId = currentUserId;
    try {
      final rows = await fetch().timeout(const Duration(seconds: 5));
      if (currentUserId != userId) throw StateError('Account gewechselt');
      await _storage.writeCache(key, rows);
      return rows;
    } catch (_) {
      if (currentUserId != userId) rethrow;
      final cached = await _storage.readCache(key);
      if (cached == null) {
        if (emptyCacheFallback != null) return emptyCacheFallback;
        rethrow;
      }
      return cached;
    }
  }

  String get currentUserId {
    final id = _client.auth.currentUser?.id;
    if (id == null) {
      throw StateError('Fuer Communities ist eine Anmeldung erforderlich.');
    }
    return id;
  }

  Future<List<Community>> loadMyCommunities() async {
    final rows = await _cachedRows(
      'communities',
      () async => await _client
          .from('community_members')
          .select('communities($communityColumns)')
          .eq('user_id', currentUserId),
    );
    return [
      for (final row in rows)
        if (row['communities'] case final Map<String, dynamic> community)
          Community.fromJson(community),
    ]..sort((a, b) => a.name.compareTo(b.name));
  }

  Future<List<CommunityRanking>> loadRankings(String communityId) async {
    final rows = await _cachedRows(
      'rankings-v1:$communityId',
      () async => await _client.from('community_rankings')
          .select('id,name').eq('community_id', communityId).order('created_at'),
    );
    final settings = await _cachedRows('ranking-settings-v1:$communityId',
      () async => await _client.from('community_ranking_settings').select().eq('community_id', communityId));
    final byId = {for (final row in settings) row['ranking_id']: row};
    return [
      for (final row in [{'id': 'default', 'name': 'Standard-Rangliste'}, ...rows])
        if (byId[row['id']]?['deleted'] != true)
          CommunityRanking.fromJson({...Map<String,dynamic>.from(row as Map),
            'validity_months': byId[row['id']]?['validity_months']}),
    ];
  }

  Future<void> saveRankingRules(String communityId, String rankingId, {int? validityMonths, bool deleted = false}) async {
    await access.require(communityId, CommunityPermission.manageRankings);
    await _client.from('community_ranking_settings').upsert({
      'community_id': communityId, 'ranking_id': rankingId,
      'validity_months': validityMonths, 'deleted': deleted,
    });
    final rows = await _client.from('community_ranking_settings').select().eq('community_id', communityId);
    await _storage.writeCache('ranking-settings-v1:$communityId', rows);
  }

  Future<CommunityRanking> createRanking(String communityId, String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty || trimmed.length > 80) {
      throw const FormatException('Bitte einen Namen mit 1 bis 80 Zeichen eingeben.');
    }
    final accountId = currentUserId;
    await access.require(communityId, CommunityPermission.editCommunity);
    final row = await _client.from('community_rankings').insert({
      'community_id': communityId, 'name': trimmed,
    }).select('id,name').single();
    if (currentUserId != accountId) throw StateError('Account wurde gewechselt.');
    try {
      final key = 'rankings-v1:$communityId';
      final cached = await _storage.readCache(key);
      // Only extend a complete cache; never replace unknown rankings with a partial list.
      if (cached != null) await _storage.writeCache(key, [...cached, row]);
    } catch (_) {
      // The ranking has already been created on the server.
    }
    return CommunityRanking.fromJson(row);
  }

  Future<Community> createCommunity({
    required String name,
    required String description,
    bool rankingEnabled = true,
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
          'ranking_enabled': rankingEnabled,
        })
        .select(communityColumns)
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
    final rows = await _cachedRows(
      'members:$communityId',
      () async => await _client
          .from('community_members')
          .select('user_id, role, joined_at, player_profiles(id, display_name)')
          .eq('community_id', communityId)
          .order('joined_at'),
    );
    final guests = await _cachedRows(
      'guest-members:$communityId',
      () async => await _client
          .from('community_guest_members')
          .select('id, display_name, linked_user_id, joined_at')
          .eq('community_id', communityId)
          .order('joined_at'),
      emptyCacheFallback: const [],
    );
    return [
      for (final guest in guests)
        CommunityMember(
          userId: null,
          playerProfileId: guest['id'] as String,
          linkedUserId: guest['linked_user_id'] as String?,
          displayName: guest['display_name'] as String,
          role: 'member',
          joinedAt: DateTime.parse(guest['joined_at'] as String),
        ),
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
    List<CreatedTournament>? remote;
    final deletedIds = <String>{};
    try {
      final rows = await _client
          .from('tournaments')
          .select('payload,is_deleted,client_tournament_id,owner_user_id')
          .eq('community_id', communityId)
          .order('updated_at', ascending: false)
          .timeout(const Duration(seconds: 5));
      remote = [
        for (final row in rows)
          if (row['is_deleted'] != true)
            if (row['payload'] case final Map<String, dynamic> payload)
              CreatedTournament.fromJson({...payload, 'access': {
                ...?payload['access'] as Map<String, dynamic>?,
                'creatorUserId': row['owner_user_id'],
              }}),
      ];
      deletedIds.addAll(
        rows
            .where((row) => row['is_deleted'] == true)
            .map((row) => row['client_tournament_id'] as String),
      );
    } catch (_) {
      // Keep saved tournaments available while the server is unreachable.
    }
    return _storage.communityTournaments(communityId, remote, deletedIds);
  }

  Future<void> addManualMember(String communityId, String name) async {
    await createManualMember(communityId, name);
  }

  Future<CommunityMember> createManualMember(String communityId, String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty || trimmed.length > 80) {
      throw ArgumentError('Bitte einen Namen mit 1 bis 80 Zeichen eingeben.');
    }
    final row = await _client.from('community_guest_members').insert({
      'community_id': communityId,
      'display_name': trimmed,
    }).select('id,display_name,joined_at').single();
    return CommunityMember(userId: null, playerProfileId: row['id'] as String,
      displayName: row['display_name'] as String, role: 'member',
      joinedAt: DateTime.parse(row['joined_at'] as String));
  }

  Future<void> assignManualMember({
    required String communityId,
    required String memberId,
    required String? userId,
  }) async {
    await _client
        .from('community_guest_members')
        .update({'linked_user_id': userId})
        .eq('community_id', communityId)
        .eq('id', memberId)
        .select('id')
        .single();
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
