import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/persistence/app_data_directory.dart';
import '../../../shared/persistence/storage_access.dart';
import '../data/backup_service.dart';
import '../data/supabase_backup_repository.dart';

/// Keeps one private complete workspace per authenticated Supabase account.
/// Local edits are uploaded after a short debounce; a newer remote snapshot is
/// pulled when the local account workspace has no unpushed edits.
class SupabaseWorkspaceSyncService {
  static final instance = SupabaseWorkspaceSyncService._();

  SupabaseWorkspaceSyncService._()
    : _repository = SupabaseBackupRepository(),
      _debounce = const Duration(seconds: 3);

  SupabaseWorkspaceSyncService({
    SupabaseBackupRepository? repository,
    Duration debounce = const Duration(seconds: 3),
  }) : _repository = repository ?? SupabaseBackupRepository(),
       _debounce = debounce;

  static final status = ValueNotifier<String>('Lokale Daten sind bereit');
  final SupabaseBackupRepository _repository;
  final Duration _debounce;
  Timer? _timer;
  bool _busy = false;
  bool _started = false;
  late final VoidCallback _changeListener = _onLocalChange;

  void start() {
    if (_started) return;
    _started = true;
    StorageAccess.localDataRevision.addListener(_changeListener);
    unawaited(_prepareAndSynchronize());
  }

  Future<void> activateAccount(String? accountId) async {
    if (accountId == null) return;
    final accountDirectory = await appDataDirectory();
    final stateFile = File(path.join(accountDirectory.path, 'supabase_sync_state.json'));
    final localWorkspaceExists = await File(path.join(accountDirectory.path, 'tournaments.json')).exists() ||
        await File(path.join(accountDirectory.path, 'app_database.sqlite')).exists();
    final legacyDirectory = await appDataDirectory(includeSupabaseAccount: false);
    final ownerMarker = File(path.join(legacyDirectory.path, 'supabase_workspace_owner'));
    if (localWorkspaceExists) {
      await ownerMarker.parent.create(recursive: true);
      if (!await ownerMarker.exists()) {
        await ownerMarker.writeAsString(accountId, flush: true);
      }
      // A previous app version may already have created this account's local
      // files without sync metadata. Treat them as unsynced edits so an older
      // cloud snapshot cannot silently replace them on first launch.
      if (!await stateFile.exists()) {
        await _writeState({'dirty': true});
      }
      return;
    }
    if (await ownerMarker.exists()) return;
    // Claim the old local-only workspace once. Do not seed another Supabase
    // account from the same legacy data directory.
    if (await _repository.hasBackup()) {
      await ownerMarker.parent.create(recursive: true);
      await ownerMarker.writeAsString(accountId, flush: true);
      return;
    }
    final files = ['tournaments.json', 'app_database.sqlite', 'planning_settings.json'];
    var copied = false;
    for (final name in files) {
      final source = File(path.join(legacyDirectory.path, name));
      if (!await source.exists()) continue;
      final target = File(path.join(accountDirectory.path, name));
      await target.parent.create(recursive: true);
      await source.copy(target.path);
      copied = true;
    }
    await ownerMarker.parent.create(recursive: true);
    await ownerMarker.writeAsString(accountId, flush: true);
    if (copied) {
      final state = await _readState();
      state['dirty'] = true;
      await _writeState(state);
      status.value = 'Bisherige lokale Daten dem Supabase-Konto zugeordnet';
    }
    // The state file is account-scoped; creating it here also makes a later
    // sync distinguish this account from the legacy local-only store.
    if (!await stateFile.exists()) await _writeState({'dirty': copied});
  }

  Future<void> _prepareAndSynchronize() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) await activateAccount(user.id);
      await synchronize();
    } catch (error) {
      status.value = 'Synchronisierung wartet auf Verbindung: $error';
    }
  }

  void _onLocalChange() {
    unawaited(_setDirty(true));
    _schedule(_debounce);
  }

  void _schedule(Duration delay) {
    _timer?.cancel();
    _timer = Timer(delay, () => unawaited(synchronize()));
  }

  Future<File> get _stateFile async => File(path.join(
    (await appDataDirectory()).path,
    'supabase_sync_state.json',
  ));

  Future<Map<String, dynamic>> _readState() async {
    final file = await _stateFile;
    if (!await file.exists()) return {};
    try {
      final json = jsonDecode(await file.readAsString());
      return json is Map<String, dynamic> ? json : {};
    } catch (_) {
      return {};
    }
  }

  Future<void> _writeState(Map<String, dynamic> value) async {
    final file = await _stateFile;
    await file.parent.create(recursive: true);
    final temp = File('${file.path}.tmp');
    await temp.writeAsString(jsonEncode(value), flush: true);
    await temp.rename(file.path);
  }

  Future<void> _setDirty(bool dirty) async {
    final state = await _readState();
    state['dirty'] = dirty;
    if (dirty) state['lastLocalChangeAt'] = DateTime.now().toUtc().toIso8601String();
    await _writeState(state);
  }

  Future<void> synchronize() async {
    if (_busy) return;
    try {
      if (Supabase.instance.client.auth.currentUser == null) {
        status.value = 'Nicht angemeldet · lokal gespeichert';
        return;
      }
    } catch (_) {
      return;
    }
    _busy = true;
    try {
      final state = await _readState();
      if (!await _repository.hasBackup()) {
        await _push(state);
        return;
      }
      final remote = await _repository.download(await BackupService.create());
      final lastSynced = DateTime.tryParse('${state['lastSyncedAt'] ?? ''}');
      final remoteIsNewer = lastSynced == null || remote.createdAt.isAfter(lastSynced);
      if (state['dirty'] == true) {
        if (remoteIsNewer) {
          status.value = 'Cloud und dieses Gerät haben Änderungen · Abgleich erforderlich';
          return;
        }
        await _push(state);
        return;
      }
      if (remoteIsNewer) {
        status.value = 'Lade neueren Datenstand aus Supabase …';
        await (await BackupService.create()).restore(remote, restartApp: false);
        await _writeState({'dirty': false, 'lastSyncedAt': remote.createdAt.toUtc().toIso8601String()});
        status.value = 'Aktueller Datenstand aus Supabase geladen';
      } else {
        status.value = 'Mit Supabase synchronisiert';
      }
    } catch (error) {
      status.value = 'Synchronisierung wartet auf Verbindung: $error';
    } finally {
      _busy = false;
    }
  }

  Future<void> _push(Map<String, dynamic> state) async {
    status.value = 'Sichere Änderungen in Supabase …';
    final timestamp = await _repository.upload(await BackupService.create());
    await _writeState({'dirty': false, 'lastSyncedAt': timestamp.toUtc().toIso8601String()});
    status.value = 'Mit Supabase synchronisiert';
  }

  /// User-confirmed resolution for simultaneous offline changes.
  Future<void> uploadLocalVersion() async {
    if (_busy) return;
    _busy = true;
    try {
      await _push(await _readState());
    } finally {
      _busy = false;
    }
  }

  /// User-confirmed resolution that replaces the local account workspace.
  Future<void> downloadRemoteVersion() async {
    if (_busy) return;
    _busy = true;
    try {
      final backups = await BackupService.create();
      final remote = await _repository.download(backups);
      await backups.restore(remote, restartApp: false);
      await _writeState({'dirty': false, 'lastSyncedAt': remote.createdAt.toUtc().toIso8601String()});
      status.value = 'Cloud-Datenstand geladen';
    } finally {
      _busy = false;
    }
  }

  void dispose() {
    _timer?.cancel();
    StorageAccess.localDataRevision.removeListener(_changeListener);
    _started = false;
  }
}
