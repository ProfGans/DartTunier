import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:sqlite3/sqlite3.dart';
import '../../tournaments/data/app_database.dart';
import '../../scorer/domain/scorer_hit.dart';

class ScorerHeatmapSession {
  ScorerHeatmapSession({
    required this.id,
    required this.date,
    required List<String> names,
    required List<ScorerHit> hits,
    this.complete = false,
  }) : names = List.unmodifiable(names),
       hits = List.unmodifiable(hits);
  final String id;
  final DateTime date;
  final List<String> names;
  final List<ScorerHit> hits;
  final bool complete;
  Map<String, dynamic> toJson() => {
    'version': 2,
    'id': id,
    'date': date.toUtc().toIso8601String(),
    'names': names,
    'hits': [for (final h in hits) h.toJson()],
    'complete': complete,
  };
  factory ScorerHeatmapSession.fromJson(Map<String, dynamic> json) {
    if (![1, 2].contains(json['version'])) {
      throw const FormatException('Unbekannte Heatmap-Version');
    }
    return ScorerHeatmapSession(
      id: json['id'] as String,
      date: DateTime.parse(json['date'] as String),
      names: List<String>.from(json['names'] as List),
      complete: json['complete'] == true,
      hits: [
        for (final raw in json['hits'] as List)
          ScorerHit.fromJson(Map<String, dynamic>.from(raw as Map)),
      ],
    );
  }
}

/// A local archive also covers guests and doubles, independently of cloud
/// account statistics. Re-saving a session replaces it, including after undo.
class ScorerHeatmapRepository {
  ScorerHeatmapRepository({LocalAppDatabase? database})
    : _database = database ?? LocalAppDatabase();
  final LocalAppDatabase _database;
  static const _key = 'scorer_heatmap_archive_v1';

  Future<void> _migrate(Database db) async {
    if (db.select('SELECT id FROM heatmap_migration WHERE id = 1').isNotEmpty) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    // Decode and validate everything before committing. Keep the original JSON
    // inside the backed-up database; never erase the legacy preference here.
    final sessions = raw == null
        ? <ScorerHeatmapSession>[]
        : await compute(_decodeLegacy, raw);
    final payloads = await compute(_encodeSessions, sessions);
    db.execute('BEGIN IMMEDIATE');
    try {
      for (var i = 0; i < sessions.length; i++) {
        db.execute(
          'INSERT OR IGNORE INTO heatmap_sessions(id, date, payload) VALUES (?, ?, ?)',
          [
            sessions[i].id,
            sessions[i].date.toUtc().toIso8601String(),
            payloads[i],
          ],
        );
      }
      db.execute(
        'INSERT INTO heatmap_migration(id, legacy_json) VALUES (1, ?)',
        [raw],
      );
      db.execute('COMMIT');
    } catch (_) {
      db.execute('ROLLBACK');
      rethrow;
    }
  }

  Future<List<ScorerHeatmapSession>> load() =>
      _database.withDatabase((db) async {
        await _migrate(db);
        final rows = db.select(
          'SELECT payload FROM heatmap_sessions ORDER BY date DESC, id',
        );
        return compute(_decodeSessions, [
          for (final row in rows) row['payload'] as String,
        ]);
      });

  static final _pending = <String, _PendingHeatmap>{};
  Future<void> save(ScorerHeatmapSession session) async {
    final path = (await _database.databaseFile()).absolute.path;
    final key = '$path\u0000${session.id}';
    final existing = _pending[key];
    if (existing != null) {
      existing.session = session;
      return existing.done.future;
    }
    final pending = _PendingHeatmap(session);
    _pending[key] = pending;
    // StorageAccess serializes backup/restore and all database writers. Updates
    // to the same waiting session share the newest snapshot and completion.
    unawaited(_storePending(key, pending));
    return pending.done.future;
  }

  Future<void> _storePending(String key, _PendingHeatmap pending) async {
    try {
      await _database.withDatabase((db) async {
        await _migrate(db);
        final session = pending.session;
        _pending.remove(key);
        if (session.hits.isEmpty) {
          db.execute('DELETE FROM heatmap_sessions WHERE id = ?', [session.id]);
        } else {
          final payload = (await compute(_encodeSessions, [session])).single;
          db.execute(
            'INSERT INTO heatmap_sessions(id, date, payload) VALUES (?, ?, ?) '
            'ON CONFLICT(id) DO UPDATE SET date=excluded.date, payload=excluded.payload '
            'WHERE payload != excluded.payload',
            [session.id, session.date.toUtc().toIso8601String(), payload],
          );
        }
      });
      pending.done.complete();
    } catch (error, stack) {
      if (identical(_pending[key], pending)) _pending.remove(key);
      pending.done.completeError(error, stack);
    }
  }
}

List<ScorerHeatmapSession> _decodeLegacy(String raw) {
  final decoded = jsonDecode(raw) as Map<String, dynamic>;
  if (decoded['version'] != 1) {
    throw const FormatException('Unbekanntes Heatmap-Archiv');
  }
  return [
    for (final item in decoded['sessions'] as List)
      ScorerHeatmapSession.fromJson(Map<String, dynamic>.from(item as Map)),
  ];
}

List<String> _encodeSessions(List<ScorerHeatmapSession> sessions) => [
  for (final session in sessions) jsonEncode(session.toJson()),
];
List<ScorerHeatmapSession> _decodeSessions(List<String> rows) => [
  for (final raw in rows)
    ScorerHeatmapSession.fromJson(jsonDecode(raw) as Map<String, dynamic>),
];

class _PendingHeatmap {
  _PendingHeatmap(this.session);
  ScorerHeatmapSession session;
  final done = Completer<void>();
}
