import '../../../shared/persistence/storage_access.dart';
import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';

import '../../../shared/persistence/app_data_directory.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/tournament_models.dart';
import '../../communities/data/community_access_repository.dart';
import '../../communities/domain/community_permissions.dart';
import '../../communities/domain/community_tournament_access.dart';

class TournamentStorage {
  TournamentStorage({
    File? file,
    String? Function()? currentUserId,
    Future<void> Function(Map<String, dynamic>)? upload,
    Future<void> Function(String, CommunityPermission)? authorize,
  }) : _file = file,
       _currentUserId = currentUserId,
       _upload = upload,
       _authorize = authorize;

  final File? _file;
  final String? Function()? _currentUserId;
  final Future<void> Function(Map<String, dynamic>)? _upload;
  final Future<void> Function(String, CommunityPermission)? _authorize;
  Future<void> _check(String communityId, CommunityPermission permission) =>
      (_authorize ?? CommunityAccessRepository(storage: this).requireCached)(
        communityId,
        permission,
      );
  static Future<void> _syncTail = Future<void>.value();
  static final syncStatus = ValueNotifier<String>('Lokal gespeichert');
  static final _acknowledgedRevisions = <String, int>{};
  String? get currentUserId => _userId;

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
    final decoded = content.length >= 256 * 1024
        ? await compute(jsonDecode, content)
        : jsonDecode(content);
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
    final encoded = await compute(_encodeTournamentDocument, document);
    await temporary.writeAsString(encoded, flush: true);
    await temporary.rename(file.path);
  }

  Future<List<dynamic>?> readCache(String key) => _locked(() async {
    final document = await _readDocument();
    return (document['cache'] as Map?)?['$_userId:$key'] as List<dynamic>?;
  });

  Future<void> writeCache(String key, List<dynamic> rows) => _locked(() async {
    final document = await _readDocument();
    final cache = Map<String, dynamic>.from(document['cache'] as Map? ?? {});
    cache['$_userId:$key'] = rows;
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
  // V7 adds account-scoped scorer histories, included in existing backups.
  // V9 adds optional RHL fixtures. Earlier tournaments keep leagueMatch = null.
  // v10 stores team rosters; older players remain individual participants.
  // v11 adds league board/scorer progress. Old leagues start without assignments.
  // v12 adds optional tournament timing and the original planning baseline.
  // v13 stores the original board-scheduled match completion timeline.
  // v16 adds resolved bot profiles. Missing profiles remain human participants.
  // v17 adds optional versioned Challonge archives. Earlier records use null.
  // The existing migration backup preserves the previous storage document.
  // v18 adds persisted board exclusions. Older tournaments have no blocked boards.
  // v19 adds tournament-specific directors and result-entry permissions.
  // v20 adds optional match starts from assigned board devices (default off).
  static const _schemaVersion = 22;

  Future<Map<String, dynamic>> readPlayerStatistics(String accountId) =>
      _locked(() async {
        final document = await _readDocument();
        final accounts = document['playerStatistics'] as Map? ?? {};
        return Map<String, dynamic>.from(accounts[accountId] as Map? ?? {});
      });

  Future<void> updatePlayerStatistics(
    String accountId,
    void Function(Map<String, dynamic>) update,
  ) => _locked(() async {
    final document = await _readDocument();
    final accounts = Map<String, dynamic>.from(
      document['playerStatistics'] as Map? ?? {},
    );
    final records = Map<String, dynamic>.from(
      accounts[accountId] as Map? ?? {},
    );
    update(records);
    accounts[accountId] = records;
    document['playerStatistics'] = accounts;
    await _writeDocument(document);
  });

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
      final previous = index < 0 ? null : tournaments[index];
      final acknowledged = _acknowledgedRevisions['$_userId:${tournament.id}'];
      if (acknowledged != null && tournament.syncRevision < acknowledged) {
        tournament.syncRevision = acknowledged;
      }
      if (tournament.communityId != null || previous?.communityId != null) {
        for (final permission in requiredTournamentPermissions(
          previous?.toJson(),
          tournament.toJson(),
        )) {
          final previousAccess = previous?.access;
          final creator =
              _userId != null && previousAccess?.creatorUserId == _userId;
          final director =
              _userId != null &&
              (previousAccess?.directorUserIds.contains(_userId) ?? false);
          if (permission == CommunityPermission.leadTournaments &&
              (creator || director)) {
            continue;
          }
          if (permission == CommunityPermission.editTournaments && creator) {
            continue;
          }
          await _check(
            previous?.communityId ?? tournament.communityId!,
            permission,
          );
        }
      }
      if (index == -1) {
        tournaments.insert(0, tournament);
      } else {
        tournaments[index] = tournament;
      }
      final document = await _readDocument();
      document['tournaments'] = tournaments
          .map((item) => item.toJson())
          .toList();
      if (tournament.communityId != null) {
        final pending = Map<String, dynamic>.from(
          document['pending'] as Map? ?? {},
        );
        pending[tournament.id] = {
          'userId': _userId,
          'payload': tournament.toJson(),
        };
        document['pending'] = pending;
      }
      // Persist the playable state and its upload together, before any network I/O.
      await _writeDocument(document);
      if (tournament.communityId != null) {
        syncStatus.value = 'Lokal gespeichert – Synchronisierung ausstehend';
      }
    });
    final complete =
        tournament.leagueMatch?.complete ??
        (tournament.runStages.isNotEmpty &&
            List.generate(
              tournament.runStages.length,
              (i) => i,
            ).every(tournament.completedStageIndexes.contains));
    if (tournament.communityId != null && complete) {
      unawaited(synchronize(tournamentId: tournament.id));
    }
  }

  Future<void> synchronize({String? tournamentId}) {
    // Queue requests rather than dropping a completion request during an upload.
    // Only disk snapshots/acknowledgements hold the storage lock, never network I/O.
    final next = _syncTail.then(
      (_) => _synchronize(tournamentId: tournamentId),
    );
    _syncTail = next.catchError((Object error) {});
    return next;
  }

  Future<void> _synchronize({String? tournamentId}) async {
    final userId = _userId;
    if (userId == null) return;
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
        int? revision;
        if (_upload != null) {
          await _upload(row).timeout(const Duration(seconds: 8));
        } else {
          revision =
              await Supabase.instance.client
                      .rpc(
                        'save_community_tournament_v2',
                        params: {'tournament_payload': tournament.toJson()},
                      )
                      .timeout(const Duration(seconds: 8))
                  as int;
        }
        await _locked(() async {
          final latest = await _readDocument();
          final remaining = Map<String, dynamic>.from(
            latest['pending'] as Map? ?? {},
          );
          if (jsonEncode(remaining[entry.key]) == jsonEncode(entry.value)) {
            remaining.remove(entry.key);
          }
          if (revision != null) {
            _acknowledgedRevisions['$userId:${tournament.id}'] = revision;
            for (final item in latest['tournaments'] as List? ?? []) {
              if (item is Map && item['id'] == tournament.id) {
                item['syncRevision'] = revision;
              }
            }
            if (remaining[entry.key] case final Map pendingEntry) {
              (pendingEntry['payload'] as Map)['syncRevision'] = revision;
            }
          }
          latest['pending'] = remaining;
          await _writeDocument(latest);
          syncStatus.value = remaining.isEmpty
              ? 'Synchronisiert'
              : 'Lokal gespeichert – Synchronisierung ausstehend';
        });
      }
    } on PostgrestException catch (error) {
      syncStatus.value = error.code == '40001'
          ? 'Konflikt: Online gibt es neuere Ergebnisse. Online-Stand laden; lokale Änderungen bleiben bis dahin erhalten.'
          : 'Synchronisierung abgelehnt. Turnierrechte und Servereinrichtung prüfen. Lokale Änderungen bleiben erhalten.';
    } catch (_) {
      syncStatus.value =
          'Lokal gespeichert – Synchronisierung ausstehend. Automatischer Wiederholungsversuch folgt.';
    }
  }

  Future<List<CreatedTournament>> communityTournaments(
    String communityId, [
    List<CreatedTournament>? remote,
    Set<String> deletedIds = const {},
  ]) => _locked(() async {
    final document = await _readDocument();
    final pending = document['pending'] as Map? ?? {};
    final local = await _loadTournamentsUnlocked();
    if (remote != null) {
      local.removeWhere(
        (item) =>
            item.communityId == communityId && deletedIds.contains(item.id),
      );
      for (final id in deletedIds) {
        pending.remove(id);
      }
      document['pending'] = pending;
      await _writeDocument(document);
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
    await _deleteTournament(id);
  }

  /// Called only after the user explicitly chooses to discard pending changes.
  Future<CreatedTournament> loadAuthoritativeTournament(
    String id,
    String communityId,
  ) {
    final next = _syncTail.then(
      (_) => _loadAuthoritativeTournament(id, communityId),
    );
    _syncTail = next.then<void>((_) {}, onError: (Object error) {});
    return next;
  }

  Future<CreatedTournament> _loadAuthoritativeTournament(
    String id,
    String communityId,
  ) async {
    final row = await Supabase.instance.client
        .from('tournaments')
        .select('payload,owner_user_id')
        .eq('client_tournament_id', id)
        .eq('community_id', communityId)
        .eq('is_deleted', false)
        .single();
    final payload = Map<String, dynamic>.from(row['payload'] as Map);
    payload['access'] = {
      ...?payload['access'] as Map<String, dynamic>?,
      'creatorUserId': row['owner_user_id'],
    };
    final remote = CreatedTournament.fromJson(payload);
    await _locked(() async {
      final document = await _readDocument();
      final list = List<dynamic>.from(document['tournaments'] as List? ?? []);
      list.removeWhere((t) => t is Map && t['id'] == id);
      list.add(remote.toJson());
      document['tournaments'] = list;
      (document['pending'] as Map?)?.remove(id);
      _acknowledgedRevisions['$_userId:$id'] = remote.syncRevision;
      await _writeDocument(document);
    });
    return remote;
  }

  Future<void> _deleteTournament(String id) async {
    await _locked(() async {
      final tournaments = await _loadTournamentsUnlocked();
      final target = tournaments.where((t) => t.id == id).firstOrNull;
      if (target?.communityId != null) {
        await _check(
          target!.communityId!,
          CommunityPermission.deleteTournaments,
        );
        // Deletion is online-only so a denied delete cannot silently erase pending work.
        await Supabase.instance.client.rpc(
          'delete_community_tournament',
          params: {
            'target_community': target.communityId!,
            'target_tournament': id,
          },
        );
      }
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
    final directory = await appDataDirectory();
    return File('${directory.path}${Platform.pathSeparator}tournaments.json');
  }
}

String _encodeTournamentDocument(Map<String, dynamic> document) =>
    jsonEncode(document);
