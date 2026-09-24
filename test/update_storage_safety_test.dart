import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:dart_tournament_manager/features/tournaments/data/app_database.dart';
import 'package:dart_tournament_manager/features/tournaments/data/tournament_storage.dart';

void main() {
  late Directory directory;
  late File file;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('update_safety');
    file = File('${directory.path}/tournaments.json');
  });
  tearDown(() => directory.delete(recursive: true));

  for (final content in ['', '[]', '{broken', '{"schemaVersion":99,"tournaments":[]}', '{"schemaVersion":6,"tournaments":[null]}']) {
    test('invalid or future document is never overwritten: $content', () async {
      await file.writeAsString(content);
      final storage = TournamentStorage(file: file);
      await expectLater(storage.loadTournaments(), throwsFormatException);
      await expectLater(storage.writeCache('test', []), throwsFormatException);
      expect(await file.readAsString(), content);
    });
  }

  test('migration preserves exact original and subsequent backup', () async {
    const original = '{"schemaVersion":1,"tournaments":[],"custom":"keep"}';
    await file.writeAsString(original);
    final storage = TournamentStorage(file: file);
    await storage.writeCache('test', [1]);
    expect(await File('${file.path}.v1.bak').readAsString(), original);
    final first = await file.readAsString();
    await storage.writeCache('test', [2]);
    expect(await File('${file.path}.bak').readAsString(), first);
    expect(await File('${file.path}.v1.bak').readAsString(), original);
    expect(jsonDecode(await file.readAsString())['custom'], 'keep');
  });

  test('newer SQLite database is rejected without changing its schema', () async {
    final path = '${directory.path}/app_database.sqlite';
    final database = sqlite3.open(path);
    database.execute('PRAGMA user_version = 99');
    database.close();
    await expectLater(LocalAppDatabase(baseDirectory: directory).loadCurrentAccount(), throwsStateError);
    final reopened = sqlite3.open(path);
    expect(reopened.select('PRAGMA user_version').first.values.single, 99);
    reopened.close();
  });

  test('SQLite migration creates a readable pre-migration backup', () async {
    final storage = LocalAppDatabase(baseDirectory: directory);
    await storage.loadCurrentAccount();
    final database = sqlite3.open('${directory.path}/app_database.sqlite');
    database.execute('DROP TABLE app_session');
    database.execute('PRAGMA user_version = 2');
    database.close();
    await storage.loadCurrentAccount();
    final backup = directory.listSync().whereType<File>().singleWhere((f) => f.path.endsWith('.bak'));
    final old = sqlite3.open(backup.path);
    expect(old.select('PRAGMA user_version').first.values.single, 2);
    old.close();
  });
}
