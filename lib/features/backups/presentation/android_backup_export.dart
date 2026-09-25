import 'package:flutter/services.dart';
import '../data/backup_service.dart';

/// Returns false when the Android document picker is cancelled.
Future<bool> exportAndroidBackup({BackupService? service}) async {
  final backups = service ?? await BackupService.create();
  final bytes = await backups.exportBytes();
  return await const MethodChannel(
        'dartturnier/backups',
      ).invokeMethod<bool>('export', bytes) ??
      false;
}
