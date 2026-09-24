import 'dart:io';
import 'package:flutter/widgets.dart';
import '../features/accounts/data/supabase_account_config.dart';
import '../features/backups/data/backup_service.dart';
import '../features/tournaments/data/tournament_storage.dart';
import '../shared/persistence/app_instance_lock.dart';

class AppBootstrap {
  AppBootstrap._();
  static AppInstanceLock? _instance;

  static Future<String?> initialize() async {
    WidgetsFlutterBinding.ensureInitialized();
    if (_instance != null) return null;
    try {
      final store = await TournamentStorage().storageFile();
      _instance = await AppInstanceLock.acquire(
        File('${store.parent.path}/app.lock'),
      );
    } catch (_) {
      return 'Die App ist bereits geöffnet oder der Datenordner ist nicht zugänglich. '
          'Schließe weitere Instanzen und starte die App erneut.';
    }
    try {
      await (await BackupService.create()).recoverInterruptedRestore();
    } catch (_) {
      return 'Eine unterbrochene Wiederherstellung konnte nicht abgeschlossen werden. '
          'Die App wurde zum Schutz der Daten nicht gestartet. '
          'Bitte den Datenordner und die Sicherungen im Unterordner backups prüfen.';
    }
    await SupabaseAccountBootstrap.initialize();
    return null;
  }
}
