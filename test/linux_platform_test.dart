import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:dart_tournament_manager/shared/persistence/app_data_directory.dart';
import 'package:dart_tournament_manager/features/notifications/data/linux_notification_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'Linux data path works without APPDATA and preserves existing legacy data',
    () async {
      final temp = await Directory.systemTemp.createTemp('linux-storage-');
      addTearDown(() => temp.delete(recursive: true));
      final support = Directory(p.join(temp.path, 'xdg'));
      Future<Directory> resolve(Map<String, String> env) => appDataDirectory(
        operatingSystem: 'linux',
        environment: env,
        supportDirectory: () async => support,
      );
      expect((await resolve({})).path, support.path);
      expect((await resolve({'APPDATA': temp.path})).path, support.path);
      final legacy = Directory(p.join(temp.path, 'DartTournamentManager'));
      await legacy.create();
      await File(
        p.join(legacy.path, 'app_database.sqlite'),
      ).writeAsString('existing');
      expect((await resolve({'APPDATA': temp.path})).path, legacy.path);
      expect(
        (await appDataDirectory(
          operatingSystem: 'windows',
          environment: {'APPDATA': temp.path},
        )).path,
        legacy.path,
      );
      await expectLater(
        appDataDirectory(operatingSystem: 'windows', environment: {}),
        throwsStateError,
      );
    },
  );
  test('systemd arguments escape spaces, specifiers and newlines', () {
    expect(LinuxNotificationService.systemdQuote(r'/home/$USER/app'), r'"/home/$$USER/app"');
    expect(
      LinuxNotificationService.systemdQuote('/home/A B/100%/"x"\n'),
      '"/home/A B/100%%/\\"x\\"\\n"',
    );
  });
}
