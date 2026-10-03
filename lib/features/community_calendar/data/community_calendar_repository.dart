import 'package:supabase_flutter/supabase_flutter.dart';
import '../../tournaments/data/tournament_storage.dart';
import '../domain/community_calendar.dart';

class CommunityCalendarRepository {
  CommunityCalendarRepository({
    SupabaseClient? client,
    TournamentStorage? storage,
  }) : _client = client,
       _storage = storage ?? TournamentStorage();
  final SupabaseClient? _client;
  final TournamentStorage _storage;
  SupabaseClient get client => _client ?? Supabase.instance.client;
  Future<void> _patchCache(
    String key,
    String id,
    Map<String, dynamic>? row, {
    String idField = 'id',
  }) async {
    final user = client.auth.currentUser?.id;
    try {
      final rows = await _storage.readCache(key);
      if (rows == null || user != client.auth.currentUser?.id) return;
      await _storage.writeCache(key, [
        for (final existing in rows)
          if ((existing as Map)[idField] != id) existing,
        ?row,
      ]);
    } catch (_) {
      // A successful server write remains successful if the optional cache is unavailable.
    }
  }

  Future<List<dynamic>> _read(
    String key,
    Future<List<dynamic>> Function() fetch,
  ) async {
    final user = client.auth.currentUser?.id;
    if (user == null) throw StateError('Bitte anmelden.');
    try {
      final rows = await fetch().timeout(const Duration(seconds: 8));
      if (user != client.auth.currentUser?.id) {
        throw StateError('Account gewechselt.');
      }
      await _storage.writeCache(key, rows);
      return rows;
    } on PostgrestException {
      rethrow;
    } catch (_) {
      if (user != client.auth.currentUser?.id) rethrow;
      final cached = await _storage.readCache(key);
      if (cached == null) rethrow;
      return cached;
    }
  }

  Future<List<CommunityCalendarEvent>> events(String communityId) async => [
    for (final row in await _read(
      'calendar-events-v1:$communityId',
      () async => await client
          .from('community_calendar_events')
          .select()
          .eq('community_id', communityId)
          .order('starts_at'),
    ))
      CommunityCalendarEvent.fromJson(Map<String, dynamic>.from(row as Map)),
  ];
  Future<List<CalendarPreset>> presets(String communityId) async => [
    for (final row in await _read(
      'calendar-presets-v1:$communityId',
      () async => await client
          .from('community_calendar_presets')
          .select()
          .eq('community_id', communityId)
          .order('name'),
    ))
      CalendarPreset.fromJson(Map<String, dynamic>.from(row as Map)),
  ];
  Future<CommunityCalendarEvent> save(
    CommunityCalendarEvent event, {
    bool create = false,
  }) async {
    final account = client.auth.currentUser?.id;
    final data = event.toJson();
    final row = create
        ? await client
              .from('community_calendar_events')
              .insert(data..remove('id'))
              .select()
              .single()
        : await client
              .from('community_calendar_events')
              .update(
                data
                  ..remove('id')
                  ..remove('community_id'),
              )
              .eq('id', event.id)
              .eq('community_id', event.communityId)
              .select()
              .single();
    if (client.auth.currentUser?.id != account) {
      throw StateError('Account gewechselt.');
    }
    await _patchCache(
      'calendar-events-v1:${event.communityId}',
      row['id'] as String,
      row,
    );
    return CommunityCalendarEvent.fromJson(row);
  }

  Future<void> delete(CommunityCalendarEvent event) async {
    final account = client.auth.currentUser?.id;
    await client
        .from('community_calendar_events')
        .delete()
        .eq('id', event.id)
        .select('id')
        .single();
    if (client.auth.currentUser?.id != account) {
      throw StateError('Account gewechselt.');
    }
    await _patchCache(
      'calendar-events-v1:${event.communityId}',
      event.id,
      null,
    );
  }

  Future<void> savePreset(
    String communityId,
    String name,
    CommunityTournamentPreset settings,
  ) async {
    final account = client.auth.currentUser?.id;
    final row = await client
        .from('community_calendar_presets')
        .insert({
          'community_id': communityId,
          'name': name.trim(),
          'settings': settings.toJson(),
        })
        .select()
        .single();
    if (client.auth.currentUser?.id != account) {
      throw StateError('Account gewechselt.');
    }
    await _patchCache(
      'calendar-presets-v1:$communityId',
      row['id'] as String,
      row,
    );
  }

  Future<Map<String, int>> reminders(String communityId) async => {
    for (final row in await _read(
      'calendar-reminders-v1:$communityId',
      () async => await client
          .from('community_calendar_reminders')
          .select('event_id,minutes_before')
          .eq('community_id', communityId),
    ))
      row['event_id'] as String: row['minutes_before'] as int,
  };
  Future<void> setReminder(CommunityCalendarEvent event, int? minutes) async {
    final account = client.auth.currentUser?.id;
    if (minutes == null) {
      await client
          .from('community_calendar_reminders')
          .delete()
          .eq('event_id', event.id)
          .eq('user_id', client.auth.currentUser!.id);
    } else {
      await client.from('community_calendar_reminders').upsert({
        'event_id': event.id,
        'community_id': event.communityId,
        'user_id': client.auth.currentUser!.id,
        'minutes_before': minutes,
      });
    }
    if (client.auth.currentUser?.id != account) {
      throw StateError('Account gewechselt.');
    }
    await _patchCache(
      'calendar-reminders-v1:${event.communityId}',
      event.id,
      minutes == null
          ? null
          : {'event_id': event.id, 'minutes_before': minutes},
      idField: 'event_id',
    );
  }
}
