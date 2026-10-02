import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/personal_profile.dart';

/// Account-scoped offline cache with a persistent upload queue.
class PersonalProfileRepository {
  PersonalProfileRepository({
    String? Function()? currentUserId,
    Future<void> Function(Map<String, dynamic>)? upload,
    Future<Map<String, dynamic>?> Function(String)? download,
  }) : _currentUserId = currentUserId,
       _upload = upload,
       _download = download;
  final String? Function()? _currentUserId;
  final Future<void> Function(Map<String, dynamic>)? _upload;
  final Future<Map<String, dynamic>?> Function(String)? _download;
  static Future<void> _queue = Future.value();
  String status = 'Lokal gespeichert';
  SupabaseClient? get _client {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  String? get _userId =>
      _currentUserId != null ? _currentUserId() : _client?.auth.currentUser?.id;
  String _key(String id) => 'personal_profile_sync_v1_$id';
  Future<Map<String, dynamic>?> _read(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final record = prefs.getString(_key(id));
    if (record != null) return jsonDecode(record) as Map<String, dynamic>;
    // Existing local profiles become pending uploads on first online use.
    final legacy = prefs.getString('personal_profile_v1_$id');
    if (legacy == null) return null;
    final payload = PersonalProfile.fromJson(
      jsonDecode(legacy) as Map<String, dynamic>,
    ).toJson();
    final migrated = {'version': 1, 'pending': true, 'payload': payload};
    await _write(id, migrated);
    return migrated;
  }

  Future<void> _write(String id, Map<String, dynamic> record) async {
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setString(_key(id), jsonEncode(record))) {
      throw StateError('Profil konnte nicht gespeichert werden');
    }
  }

  Future<PersonalProfile> load(String accountId, String defaultName) async {
    await synchronize(accountId);
    final record = await _read(accountId);
    return record == null
        ? PersonalProfile(name: defaultName)
        : PersonalProfile.fromJson(
            Map<String, dynamic>.from(record['payload'] as Map),
          );
  }

  Future<void> save(String accountId, PersonalProfile profile) async {
    await _write(accountId, {
      'version': 1,
      'pending': true,
      'payload': profile.toJson(),
    });
    await synchronize(accountId);
  }

  Future<void> synchronize(String accountId) {
    if (_userId != accountId) {
      status = 'Lokal gespeichert · kein passender Online-Account angemeldet';
      return Future.value();
    }
    final result = _queue.then((_) => _synchronize(accountId));
    _queue = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<void> _synchronize(String id) async {
    if (_userId != id) {
      status = 'Lokal gespeichert · kein passender Online-Account angemeldet';
      return;
    }
    try {
      final record = await _read(id);
      if (record?['pending'] == true) {
        if (_userId != id) return;
        final row = <String, dynamic>{
          'owner_user_id': id,
          'payload': record!['payload'],
        };
        if (_upload != null) {
          await _upload(row).timeout(const Duration(seconds: 8));
        } else {
          await _client!
              .from('personal_profiles')
              .upsert(row, onConflict: 'owner_user_id')
              .timeout(const Duration(seconds: 8));
        }
        if (_userId != id) return;
        final latest = await _read(id);
        if (jsonEncode(latest) == jsonEncode(record)) {
          await _write(id, {...record, 'pending': false});
        }
      }
      if (_userId != id) return;
      final row = _download != null
          ? await _download(id).timeout(const Duration(seconds: 8))
          : await _client!
                .from('personal_profiles')
                .select('owner_user_id,payload')
                .eq('owner_user_id', id)
                .maybeSingle()
                .timeout(const Duration(seconds: 8));
      if (_userId != id) return;
      if (row != null) {
        if (row['owner_user_id'] != id) {
          throw const FormatException('Ungültige Profilzuordnung');
        }
        final profile = PersonalProfile.fromJson(
          Map<String, dynamic>.from(row['payload'] as Map),
        );
        final latest = await _read(id);
        if (latest?['pending'] != true) {
          await _write(id, {
            'version': 1,
            'pending': false,
            'payload': profile.toJson(),
          });
        }
      }
      final latest = await _read(id);
      status = latest?['pending'] == true
          ? 'Lokal gespeichert · Online-Speicherung ausstehend'
          : latest == null
          ? 'Online verbunden · noch kein Profil gespeichert'
          : 'Profil online gespeichert';
    } catch (_) {
      status =
          'Lokal verfügbar · Online-Abgleich fehlgeschlagen. Bitte erneut versuchen.';
    }
  }
}
