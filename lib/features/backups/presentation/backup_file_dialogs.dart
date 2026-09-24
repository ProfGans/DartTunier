import 'package:file_selector/file_selector.dart';

/// Native dialogs are separate from the backup UI and storage transaction.
class BackupFileDialogs {
  const BackupFileDialogs();
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
