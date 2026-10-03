import 'package:supabase_flutter/supabase_flutter.dart';
import '../../communities/data/community_access_repository.dart';
import '../../communities/domain/community_permissions.dart';
import '../../tournaments/data/tournament_storage.dart';
import '../domain/community_highlight.dart';

class CommunityHighlightsRepository {
  CommunityHighlightsRepository({
    SupabaseClient? client,
    TournamentStorage? storage,
  }) : _client = client,
       _storage = storage ?? TournamentStorage();
  final SupabaseClient? _client;
  final TournamentStorage _storage;
  SupabaseClient get client => _client ?? Supabase.instance.client;
  String get _user =>
      client.auth.currentUser?.id ??
      (throw StateError('Anmeldung erforderlich'));
  bool cached = false;
  String _key(String user, String community) =>
      'community-highlights-v1:$user:$community';
  Future<bool> canManage(String community) async =>
      (await CommunityAccessRepository(
        client: client,
      ).permissions(community)).allows(CommunityPermission.manageHighlights);

  Future<List<CommunityHighlight>> load(String community) async {
    final user = _user;
    List<dynamic> rows;
    cached = false;
    try {
      rows = [];
      for (var offset = 0; ; offset += 1000) {
        final page = await client
            .from('community_highlights')
            .select()
            .eq('community_id', community)
            .order('highlight_key')
            .range(offset, offset + 999)
            .timeout(const Duration(seconds: 5));
        rows.addAll(page);
        if (page.length < 1000) break;
      }
    } on PostgrestException {
      rethrow;
    } catch (_) {
      if (_user != user) rethrow;
      final saved = await _storage.readCache(_key(user, community));
      if (saved == null) rethrow;
      rows = saved;
      cached = true;
    }
    if (_user != user) throw StateError('Account gewechselt');
    await _storage.writeCache(_key(user, community), rows);
    return rows
        .map(
          (r) =>
              CommunityHighlight.fromJson(Map<String, dynamic>.from(r as Map)),
        )
        .toList();
  }

  Future<CommunityHighlight> save(
    String community,
    CommunityHighlight highlight,
  ) async {
    final user = _user;
    await CommunityAccessRepository(
      client: client,
    ).require(community, CommunityPermission.manageHighlights);
    final row = await client
        .from('community_highlights')
        .upsert({
          'community_id': community,
          ...highlight.toJson(),
        }, onConflict: 'community_id,highlight_key')
        .select()
        .single();
    if (_user != user) throw StateError('Account gewechselt');
    try {
      final key = _key(user, community);
      final saved = await _storage.readCache(key);
      if (saved != null) {
        await _storage.writeCache(key, [
          for (final item in saved)
            if ((item as Map)['highlight_key'] != highlight.key) item,
          row,
        ]);
      }
    } catch (_) {
      /* The server already saved the change. */
    }
    return CommunityHighlight.fromJson(row);
  }
}
