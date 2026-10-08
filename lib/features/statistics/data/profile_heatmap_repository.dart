import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../tournaments/data/app_database.dart';
import 'scorer_heatmap_repository.dart';

/// Private account snapshots; empty hits are durable tombstones after undo.
class ProfileHeatmapRepository {
  ProfileHeatmapRepository({
    LocalAppDatabase? database,
    String? Function()? currentUserId,
    Future<void> Function(Map<String, dynamic>)? upload,
    Future<List<Map<String, dynamic>>> Function(String)? download,
  }) : database = database ?? LocalAppDatabase(),
       _currentUserId = currentUserId,
       _upload = upload,
       _download = download;
  final LocalAppDatabase database;
  final String? Function()? _currentUserId;
  final Future<void> Function(Map<String, dynamic>)? _upload;
  final Future<List<Map<String, dynamic>>> Function(String)? _download;
  static Future<void> _queue = Future.value();
  String status = 'Heatmaps lokal gespeichert';
  SupabaseClient? get _client {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  String? get _user =>
      _currentUserId != null ? _currentUserId() : _client?.auth.currentUser?.id;
  Future<void> save(
    String owner,
    ScorerHeatmapSession session,
    int playerIndex, {
    bool onlyIfAbsent = false,
  }) async {
    final scoped = ScorerHeatmapSession(
      id: session.id,
      date: session.date,
      names: session.names,
      hits: session.hits.where((h) => h.player == playerIndex).toList(),
      complete: session.complete,
    );
    final payload = jsonEncode(scoped.toJson());
    await database.withDatabase((db) async {
      db.execute(
        onlyIfAbsent
            ? 'INSERT OR IGNORE INTO profile_heatmaps(owner_user_id,session_id,payload,pending) VALUES (?,?,?,1)'
            : 'INSERT INTO profile_heatmaps(owner_user_id,session_id,payload,pending) VALUES (?,?,?,1) ON CONFLICT(owner_user_id,session_id) DO UPDATE SET payload=excluded.payload,pending=1 WHERE payload != excluded.payload',
        [owner, session.id, payload],
      );
    });
  }

  Future<List<ScorerHeatmapSession>> load(
    String owner,
  ) => database.withDatabase(
    (db) async => [
      for (final row in db.select(
        'SELECT payload FROM profile_heatmaps WHERE owner_user_id=? ORDER BY session_id',
        [owner],
      ))
        ScorerHeatmapSession.fromJson(
          jsonDecode(row['payload'] as String) as Map<String, dynamic>,
        ),
    ],
  );
  Future<void> synchronize(String owner) {
    final run = _queue.then((_) => _sync(owner));
    _queue = run.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return run;
  }

  Future<void> _sync(String owner) async {
    if (_user != owner) {
      status = 'Heatmaps lokal gespeichert · kein passender Online-Account';
      return;
    }
    try {
      final pending = await database.withDatabase(
        (db) async => [
          for (final row in db.select(
            'SELECT session_id,payload FROM profile_heatmaps WHERE owner_user_id=? AND pending=1',
            [owner],
          ))
            (
              id: row['session_id'] as String,
              payload: row['payload'] as String,
            ),
        ],
      );
      for (final row in pending) {
        if (_user != owner) return;
        final data = <String, dynamic>{
          'owner_user_id': owner,
          'session_id': row.id,
          'payload': jsonDecode(row.payload),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        };
        if (_upload != null) {
          await _upload(data);
        } else {
          await _client!
              .from('profile_heatmaps')
              .upsert(data, onConflict: 'owner_user_id,session_id')
              .timeout(const Duration(seconds: 8));
        }
        if (_user != owner) return;
        await database.withDatabase(
          (db) async => db.execute(
            'UPDATE profile_heatmaps SET pending=0 WHERE owner_user_id=? AND session_id=? AND payload=?',
            [owner, row.id, row.payload],
          ),
        );
      }
      final rows = <Map<String, dynamic>>[];
      if (_download != null) {
        rows.addAll(await _download(owner));
      } else {
        for (var offset = 0; ; offset += 200) {
          if (_user != owner) return;
          final page = await _client!
              .from('profile_heatmaps')
              .select('owner_user_id,session_id,payload')
              .eq('owner_user_id', owner)
              .order('session_id')
              .range(offset, offset + 199)
              .timeout(const Duration(seconds: 8));
          rows.addAll(page);
          if (page.length < 200) break;
        }
      }
      if (_user != owner) return;
      final parsed = [
        for (final row in rows)
          (
            owner: row['owner_user_id'],
            id: row['session_id'],
            session: ScorerHeatmapSession.fromJson(
              Map<String, dynamic>.from(row['payload'] as Map),
            ),
          ),
      ];
      if (parsed.any((row) => row.owner != owner || row.id != row.session.id)) {
        throw const FormatException('Ungültige Heatmap-Zuordnung');
      }
      await database.withDatabase((db) async {
        db.execute('BEGIN IMMEDIATE');
        try {
          for (final row in parsed) {
            db.execute(
              'INSERT INTO profile_heatmaps(owner_user_id,session_id,payload,pending) VALUES (?,?,?,0) ON CONFLICT(owner_user_id,session_id) DO UPDATE SET payload=excluded.payload WHERE pending=0',
              [owner, row.id, jsonEncode(row.session.toJson())],
            );
          }
          db.execute('COMMIT');
        } catch (_) {
          db.execute('ROLLBACK');
          rethrow;
        }
      });
      final remaining = await database.withDatabase(
        (db) async => db.select(
          'SELECT session_id FROM profile_heatmaps WHERE owner_user_id=? AND pending=1 LIMIT 1',
          [owner],
        ).isNotEmpty,
      );
      status = remaining
          ? 'Heatmap-Synchronisierung ausstehend'
          : 'Heatmaps synchronisiert';
    } catch (_) {
      status = 'Heatmaps lokal gesichert · Online-Abgleich ausstehend';
    }
  }
}
