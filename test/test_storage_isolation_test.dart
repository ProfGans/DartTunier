import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_tournament_manager/shared/persistence/app_data_directory.dart';

void main() {
  test('test autosave cannot access real APPDATA and uses one stable directory', () async {
    final dirs = await Future.wait(List.generate(10, (_) => appDataDirectory()));
    expect(dirs.map((d) => d.path).toSet(), hasLength(1));
    expect(dirs.first.path, startsWith(Directory.systemTemp.path));
    final appdata = Platform.environment['APPDATA'];
    if (appdata != null) {
      expect(dirs.first.path, isNot(startsWith('$appdata${Platform.pathSeparator}DartTournamentManager')));
    }
  });
}
