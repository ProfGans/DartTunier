import 'dart:io';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'backup_service.dart';

class SupabaseBackupRepository {
  SupabaseBackupRepository({SupabaseClient? client})
    : _injectedClient = client;

  static const bucket = 'dart-app-backups';
  static const fileName = 'latest.dartbackup';
  final SupabaseClient? _injectedClient;
  SupabaseClient get _client => _injectedClient ?? Supabase.instance.client;

  String get _objectPath {
    final user = _client.auth.currentUser;
    if (user == null) throw StateError('Bitte zuerst als Betreiber anmelden.');
    return '${user.id}/$fileName';
  }

  Future<bool> hasBackup() async {
    final user = _client.auth.currentUser;
    if (user == null) throw StateError('Bitte zuerst als Betreiber anmelden.');
    final files = await _client.storage.from(bucket).list(path: user.id);
    return files.any((file) => file.name == fileName);
  }

  Future<DateTime> upload(BackupService backups) async {
    final bytes = await backups.exportBytes();
    final preview = await backups.inspect(bytes);
    await _client.storage.from(bucket).uploadBinary(
      _objectPath,
      bytes,
      fileOptions: const FileOptions(
        upsert: true,
        contentType: 'application/octet-stream',
      ),
    );
    return preview.createdAt;
  }

  Future<BackupPreview> download(BackupService backups) async {
    final Uint8List bytes = await _client.storage.from(bucket).download(_objectPath);
    return backups.inspect(bytes);
  }

  Future<File> restore(BackupService backups, BackupPreview preview) =>
      backups.restore(preview);
}
