import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../scorer/domain/scorer_hit.dart';

class ScorerHeatmapSession {
  const ScorerHeatmapSession({
    required this.id,
    required this.date,
    required this.names,
    required this.hits,
    this.complete = false,
  });
  final String id;
  final DateTime date;
  final List<String> names;
  final List<ScorerHit> hits;
  final bool complete;
  Map<String, dynamic> toJson() => {
    'version': 1,
    'id': id,
    'date': date.toUtc().toIso8601String(),
    'names': names,
    'hits': [for (final h in hits) h.toJson()],
    'complete': complete,
  };
  factory ScorerHeatmapSession.fromJson(Map<String, dynamic> json) {
    if (json['version'] != 1) {
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
  static const _key = 'scorer_heatmap_archive_v1';
  static Future<void> _queue = Future.value();
  Future<List<ScorerHeatmapSession>> load() async {
    await _queue;
    return _read(await SharedPreferences.getInstance());
  }

  List<ScorerHeatmapSession> _read(SharedPreferences prefs) {
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    if (decoded['version'] != 1) {
      throw const FormatException('Unbekanntes Heatmap-Archiv');
    }
    return [
      for (final item in decoded['sessions'] as List)
        ScorerHeatmapSession.fromJson(Map<String, dynamic>.from(item as Map)),
    ]..sort((a, b) => b.date.compareTo(a.date));
  }

  Future<void> save(ScorerHeatmapSession session) {
    final next = _queue.then((_) async {
      final prefs = await SharedPreferences.getInstance();
      final sessions = {for (final s in _read(prefs)) s.id: s};
      if (session.hits.isEmpty) {
        sessions.remove(session.id);
      } else {
        sessions[session.id] = session;
      }
      if (!await prefs.setString(
        _key,
        jsonEncode({
          'version': 1,
          'sessions': [for (final s in sessions.values) s.toJson()],
        }),
      )) {
        throw StateError('Heatmap konnte nicht gespeichert werden');
      }
    });
    _queue = next.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return next;
  }
}
