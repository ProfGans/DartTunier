import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../shared/persistence/storage_access.dart';
import '../data/backup_service.dart';

/// Resets this installation's local stores after creating a recovery backup.
class LocalAppResetService {
  const LocalAppResetService();

  Future<File> reset() async {
    final backup = await BackupService.create();
    return StorageAccess.run(() async {
      final bytes = await backup.exportBytes();
      await backup.backupDirectory.create(recursive: true);
      final timestamp = DateTime.now()
          .toUtc()
          .toIso8601String()
          .replaceAll(':', '-')
          .replaceAll('.', '-');
      final archive = File(
        path.join(backup.backupDirectory.path, 'factory-reset-$timestamp.dartbackup'),
      );
      await archive.writeAsBytes(bytes, flush: true);

      for (final store in backup.files.values) {
        for (final suffix in ['', '.bak', '.tmp', '-wal', '-shm']) {
          final file = File('${store.path}$suffix');
          if (await file.exists()) await file.delete();
        }
        final parent = store.parent;
        if (await parent.exists()) {
          final base = path.basename(store.path);
          await for (final entity in parent.list(followLinks: false)) {
            if (entity is File &&
                path.basename(entity.path).startsWith('$base.v') &&
                path.basename(entity.path).endsWith('.bak')) {
              await entity.delete();
            }
          }
        }
      }
      await (await SharedPreferences.getInstance()).clear();
      StorageAccess.requireRestart(
        'Die lokalen App-Daten wurden zurückgesetzt. Ein Backup liegt unter ${archive.path}. Bitte starte die App neu.',
      );
      return archive;
    });
  }
}
