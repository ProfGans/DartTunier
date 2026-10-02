import 'package:file_selector/file_selector.dart';
import 'dart:io';
import '../data/backup_service.dart';

/// Native dialogs are separate from the backup UI and storage transaction.
class BackupFileDialogs {
  const BackupFileDialogs();
  Future<bool> export(BackupService service) async {
    final path = await savePath();
    if (path == null) return false;
    await File(path).writeAsBytes(await service.exportBytes(), flush: true);
    return true;
  }

  static const type = XTypeGroup(
    label: 'Turnier-Backup',
    extensions: ['dartbackup'],
    uniformTypeIdentifiers: ['public.data'],
  );

  Future<String?> savePath() async {
    final location = await getSaveLocation(
      suggestedName:
          'Turniere_${DateTime.now().toIso8601String().replaceAll(':', '-')}.dartbackup',
      acceptedTypeGroups: [type],
      confirmButtonText: 'Backup speichern',
    );
    return location?.path;
  }

  Future<XFile?> open() =>
      openFile(acceptedTypeGroups: [type], confirmButtonText: 'Backup prüfen');
}
