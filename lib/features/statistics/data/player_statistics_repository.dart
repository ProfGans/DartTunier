import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../tournaments/data/tournament_storage.dart';
import '../domain/saved_scorer_match.dart';

/// Local-first, account-scoped snapshots. Network work never holds the disk lock.
class PlayerStatisticsRepository {
  PlayerStatisticsRepository({
    TournamentStorage? storage,
    SupabaseClient? client,
    String? Function()? currentUserId,
    Future<void> Function(Map<String, dynamic>)? upload,
    Future<List<Map<String, dynamic>>> Function(String)? download,
  }) : storage = storage ?? TournamentStorage(),
       _clientOverride = client,
       _currentUserId = currentUserId,
       _upload = upload,
       _download = download;
  final TournamentStorage storage;
  final SupabaseClient? _clientOverride;
  final String? Function()? _currentUserId;
  final Future<void> Function(Map<String, dynamic>)? _upload;
  final Future<List<Map<String, dynamic>>> Function(String)? _download;
  String? get _accountId =>
      _currentUserId != null ? _currentUserId() : _client?.auth.currentUser?.id;
  String status = 'Lokal gespeichert';
  static Future<void> _syncQueue = Future.value();
  SupabaseClient? get _client {
    if (_clientOverride != null) return _clientOverride;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  Future<void> save(SavedScorerMatch match) => storage.updatePlayerStatistics(
    match.accountId,
    (records) =>
        records[match.id] = {'pending': true, 'payload': match.toJson()},
  );

  Future<List<SavedScorerMatch>> load(String accountId) async {
    final records = await storage.readPlayerStatistics(accountId);
    return [
      for (final value in records.values)
        SavedScorerMatch.fromJson(
          Map<String, dynamic>.from(value['payload'] as Map),
        ),
    ]..sort((a, b) => b.playedAt.compareTo(a.playedAt));
  }

  Future<void> synchronize(String accountId) {
    final result = _syncQueue.then((_) => _synchronize(accountId));
    _syncQueue = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return result;
  }

  Future<void> _synchronize(String accountId) async {
    final client = _client;
    if (_accountId != accountId) {
      status = 'Lokal gespeichert · kein passender Online-Account angemeldet';
      return;
    }
    try {
      final records = await storage.readPlayerStatistics(accountId);
      for (final entry in records.entries) {
        if (_accountId != accountId) return;
        if (entry.value['pending'] != true) continue;
        final payload = entry.value['payload'];
        final row = <String, dynamic>{
          'owner_user_id': accountId,
          'session_id': entry.key,
          'payload': payload,
        };
        if (_upload != null) {
          await _upload(row);
        } else {
          await client!
              .from('player_match_statistics')
              .upsert(row, onConflict: 'owner_user_id,session_id')
              .timeout(const Duration(seconds: 8));
        }
        await storage.updatePlayerStatistics(accountId, (latest) {
          if (jsonEncode(latest[entry.key]) == jsonEncode(entry.value)) {
            latest[entry.key] = {'pending': false, 'payload': payload};
          }
        });
      }
      if (_accountId != accountId) return;
      final rows = _download != null
          ? await _download(accountId)
          : await _downloadAll(client!, accountId);
      if (_accountId != accountId) return;
      await storage.updatePlayerStatistics(accountId, (latest) {
        for (final row in rows) {
          final id = row['session_id'] as String;
          if (latest[id]?['pending'] == true) continue;
          final parsed = SavedScorerMatch.fromJson(
            Map<String, dynamic>.from(row['payload'] as Map),
          );
          if (parsed.accountId != accountId || parsed.id != id) {
            throw const FormatException('Ungültige Statistikzuordnung');
          }
          latest[id] = {'pending': false, 'payload': parsed.toJson()};
        }
      });
      final latest = await storage.readPlayerStatistics(accountId);
      status = latest.values.any((v) => v['pending'] == true)
          ? 'Lokal gespeichert · Synchronisierung ausstehend'
          : 'Synchronisiert';
    } catch (_) {
      status =
          'Lokal gespeichert · Online-Abgleich fehlgeschlagen. Bitte erneut versuchen.';
    }
  }

  Future<List<Map<String, dynamic>>> _downloadAll(
    SupabaseClient client,
    String accountId,
  ) async {
    final result = <Map<String, dynamic>>[];
    for (var offset = 0; ; offset += 500) {
      if (_accountId != accountId) throw StateError('Account gewechselt');
      final page = await client
          .from('player_match_statistics')
          .select('session_id,payload')
          .eq('owner_user_id', accountId)
          .order('session_id')
          .range(offset, offset + 499)
          .timeout(const Duration(seconds: 8));
      result.addAll(page);
      if (page.length < 500) return result;
    }
  }
}
