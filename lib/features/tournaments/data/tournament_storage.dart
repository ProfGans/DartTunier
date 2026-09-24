import '../../../shared/persistence/storage_access.dart';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/tournament_models.dart';

class TournamentStorage {
  TournamentStorage({
    File? file,
    String? Function()? currentUserId,
    Future<void> Function(Map<String, dynamic>)? upload,
  }) : _file = file,
       _currentUserId = currentUserId,
       _upload = upload;

  final File? _file;
  final String? Function()? _currentUserId;
  final Future<void> Function(Map<String, dynamic>)? _upload;
  static bool _syncing = false;
  static final syncStatus = ValueNotifier<String>('Lokal gespeichert');

  String? get _userId {
    if (_currentUserId != null) return _currentUserId();
    try {
      return Supabase.instance.client.auth.currentUser?.id;
    } catch (_) {
      return null;
    }
  }

  Future<T> _locked<T>(Future<T> Function() action) =>
      StorageAccess.run(action);

  Future<Map<String, dynamic>> _readDocument() async {
    final file = await _storageFile();
    if (!await file.exists()) return {};
    final content = await file.readAsString();
    final decoded = jsonDecode(content);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Ungültiger Turnierspeicher');
    }
    final version = decoded['schemaVersion'] ?? 1;
    if (version is! int || version < 1 || version > _schemaVersion) {
      throw const FormatException(
        'Nicht unterstützte Speicherversion. Bitte App aktualisieren.',
      );
    }
    final tournaments = decoded['tournaments'];
    if (tournaments != null &&
        (tournaments is! List ||
            tournaments.any((item) => item is! Map<String, dynamic>))) {
      throw const FormatException('Beschädigte Turnierliste');
    }
    return decoded;
  }

  Future<void> _writeDocument(Map<String, dynamic> document) async {
    final file = await _storageFile();
    await file.parent.create(recursive: true);
    if (await file.exists()) {
      final previous = await _readDocument();
      await file.copy('${file.path}.bak');
      final version = previous['schemaVersion'] ?? 1;
      final migrationBackup = File('${file.path}.v$version.bak');
      if (version < _schemaVersion && !await migrationBackup.exists()) {
        await file.copy(migrationBackup.path);
      }
    }
    document['schemaVersion'] = _schemaVersion;
    final temporary = File('${file.path}.tmp');
    await temporary.writeAsString(jsonEncode(document), flush: true);
    await temporary.rename(file.path);
  }

  Future<List<dynamic>?> readCache(String key) => _locked(() async {
    final document = await _readDocument();
    return (document['cache'] as Map?)?['${_userId}:$key'] as List<dynamic>?;
  });

  Future<void> writeCache(String key, List<dynamic> rows) => _locked(() async {
    final document = await _readDocument();
    final cache = Map<String, dynamic>.from(document['cache'] as Map? ?? {});
    cache['${_userId}:$key'] = rows;
    document['cache'] = cache;
    await _writeDocument(document);
  });
  // V2 adds board count and match start/completion metadata. Missing V1 fields
  // migrate through model defaults (one board, no recorded match times).
  // V3 adds sets per stage and optional set results. V1/V2 migrate to one
  // set (leg-only matches) and null set scores through model defaults.
  // V4 adds an outbox and account-scoped read caches. V1-V3 have neither.
  // V5 stores final rules and lives. Missing fields keep legacy life-based finals.
  // V6 adds optional placement selections and classification match identities.
  static const _schemaVersion = 6;

  Future<List<CreatedTournament>> loadTournaments() =>
      _locked(_loadTournamentsUnlocked);

  Future<List<CreatedTournament>> _loadTournamentsUnlocked() async {
    final decoded = await _readDocument();
    final tournamentJson = decoded['tournaments'] as List? ?? [];

    return [
      for (final item in tournamentJson)
        if (item is Map<String, dynamic>) CreatedTournament.fromJson(item),
    ]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  Future<void> saveTournament(CreatedTournament tournament) async {
    await _locked(() async {
      final tournaments = await _loadTournamentsUnlocked();
      tournament.updatedAt = DateTime.now();
      final index = tournaments.indexWhere((item) => item.id == tournament.id);
      if (index == -1) {
        tournaments.insert(0, tournament);
      } else {
        tournaments[index] = tournament;
      }
      await _writeTournaments(tournaments);
      if (tournament.communityId != null) {
        final document = await _readDocument();
        final pending = Map<String, dynamic>.from(
          document['pending'] as Map? ?? {},
        );
        pending[tournament.id] = {
          'userId': _userId,
          'payload': tournament.toJson(),
        };
        document['pending'] = pending;
        await _writeDocument(document);
        syncStatus.value = 'Lokal gespeichert – Synchronisierung ausstehend';
      }
    });
  }

  Future<void> synchronize({String? tournamentId}) =>
      StorageAccess.run(() => _synchronize(tournamentId: tournamentId));

  Future<void> _synchronize({String? tournamentId}) async {
    final userId = _userId;
    if (_syncing || userId == null) return;
    _syncing = true;
    try {
      final document = await _locked(_readDocument);
      final pending = Map<String, dynamic>.from(
        document['pending'] as Map? ?? {},
      );
      for (final entry in pending.entries) {
        if (tournamentId != null && entry.key != tournamentId) continue;
        final value = Map<String, dynamic>.from(entry.value as Map);
        if (value['userId'] != userId) continue;
        if (_userId != userId) return;
        final tournament = CreatedTournament.fromJson(
          Map<String, dynamic>.from(value['payload'] as Map),
        );
        final row = <String, dynamic>{
          'client_tournament_id': tournament.id,
          'owner_user_id': userId,
          'community_id': tournament.communityId,
          'name': tournament.name,
          'payload': tournament.toJson(),
          'is_deleted': false,
        };
        if (_upload != null) {
          await _upload(row);
        } else {
          await Supabase.instance.client
              .from('tournaments')
              .upsert(row, onConflict: 'client_tournament_id')
              .timeout(const Duration(seconds: 8));
        }
        await _locked(() async {
          final latest = await _readDocument();
          final remaining = Map<String, dynamic>.from(
            latest['pending'] as Map? ?? {},
          );
          if (jsonEncode(remaining[entry.key]) == jsonEncode(entry.value)) {
            remaining.remove(entry.key);
          }
          latest['pending'] = remaining;
          await _writeDocument(latest);
          syncStatus.value = remaining.isEmpty
              ? 'Synchronisiert'
              : 'Lokal gespeichert – Synchronisierung ausstehend';
        });
      }
    } catch (_) {
      syncStatus.value =
          'Lokal gespeichert – Synchronisierung fehlgeschlagen. Bitte manuell erneut versuchen.';
    } finally {
      _syncing = false;
    }
  }

  Future<List<CreatedTournament>> communityTournaments(
    String communityId, [
    List<CreatedTournament>? remote,
  ]) => _locked(() async {
    final document = await _readDocument();
    final pending = document['pending'] as Map? ?? {};
    final local = await _loadTournamentsUnlocked();
    if (remote != null) {
      for (final tournament in remote) {
        if (pending.containsKey(tournament.id)) continue;
        local.removeWhere((item) => item.id == tournament.id);
        local.add(tournament);
      }
      await _writeTournaments(local);
    }
    return local.where((item) => item.communityId == communityId).toList();
  });

  Future<void> deleteTournament(String id) async {
    await _locked(() async {
      final tournaments = await _loadTournamentsUnlocked();
      tournaments.removeWhere((tournament) => tournament.id == id);
      await _writeTournaments(tournaments);
      final document = await _readDocument();
      (document['pending'] as Map?)?.remove(id);
      await _writeDocument(document);
    });
  }

  Future<void> _writeTournaments(List<CreatedTournament> tournaments) async {
    final document = await _readDocument();
    document['tournaments'] = tournaments.map((item) => item.toJson()).toList();
    await _writeDocument(document);
  }

  Future<File> storageFile() => _storageFile();

  Future<File> _storageFile() async {
    if (_file != null) return _file;
    if (Platform.isAndroid || Platform.isIOS || Platform.isMacOS) {
      final directory = await _applicationSupportDirectory();
      return File('${directory.path}${Platform.pathSeparator}tournaments.json');
    }

    final appData = Platform.environment['APPDATA'];
    final basePath = appData == null || appData.isEmpty
        ? (throw StateError(
            'APPDATA fehlt; Speicherort kann nicht sicher bestimmt werden.',
          ))
        : appData;
    return File(
      '$basePath${Platform.pathSeparator}DartTournamentManager'
      '${Platform.pathSeparator}tournaments.json',
    );
  }

  Future<Directory> _applicationSupportDirectory() async {
    return getApplicationSupportDirectory();
  }
}
