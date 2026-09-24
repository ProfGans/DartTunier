import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../tournaments/domain/tournament_models.dart';
import '../../tournaments/data/tournament_storage.dart';
import '../domain/community.dart';

class SupabaseCommunityRepository {
  SupabaseCommunityRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;
  final TournamentStorage _storage = TournamentStorage();

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
          .select('communities(*)')
          .eq('user_id', currentUserId),
    );
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
    try {
      final rows = await _client
          .from('tournaments')
          .select('payload')
          .eq('community_id', communityId)
          .eq('is_deleted', false)
          .order('updated_at', ascending: false)
          .timeout(const Duration(seconds: 5));
      remote = [
        for (final row in rows)
          if (row['payload'] case final Map<String, dynamic> payload)
            CreatedTournament.fromJson(payload),
      ];
    } catch (_) {
      // Keep saved tournaments available while the server is unreachable.
    }
    return _storage.communityTournaments(communityId, remote);
  }

  Future<void> addManualMember(String communityId, String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty || trimmed.length > 80) {
      throw ArgumentError('Bitte einen Namen mit 1 bis 80 Zeichen eingeben.');
    }
    await _client.from('community_guest_members').insert({
      'community_id': communityId,
      'display_name': trimmed,
    });
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
