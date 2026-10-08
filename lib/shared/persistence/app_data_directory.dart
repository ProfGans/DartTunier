import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

Future<Directory>? _isolatedTestDirectory;

/// One location for the database, tournament JSON and the restore lock.
/// Preserve explicitly configured legacy Linux installations without copying
/// an open database or silently splitting existing data across two directories.
Future<Directory> appDataDirectory({
  String? operatingSystem,
  Map<String, String>? environment,
  Future<Directory> Function()? supportDirectory,
}) async {
  final os = operatingSystem ?? Platform.operatingSystem;
  final env = environment ?? Platform.environment;
  // Widget tests may exercise autosave. Never let the Windows APPDATA shortcut
  // bypass their mocked path provider and write into a real user's database.
  if (Platform.environment.containsKey('FLUTTER_TEST') &&
      environment == null && operatingSystem == null) {
    if (supportDirectory != null) return supportDirectory();
    return _isolatedTestDirectory ??=
        Directory.systemTemp.createTemp('dart_tournament_test_');
  }
  final legacy = env['APPDATA'];
  if (os == 'windows') {
    if (legacy == null || legacy.isEmpty) {
      throw StateError('APPDATA fehlt; kein sicherer Speicherort.');
    }
    return Directory(p.join(legacy, 'DartTournamentManager'));
  }
  if (os == 'linux' && legacy != null && legacy.isNotEmpty) {
    final directory = Directory(p.join(legacy, 'DartTournamentManager'));
    if (await File(p.join(directory.path, 'tournaments.json')).exists() ||
        await File(p.join(directory.path, 'app_database.sqlite')).exists()) {
      return directory;
    }
  }
  return (supportDirectory ?? getApplicationSupportDirectory)();
}
