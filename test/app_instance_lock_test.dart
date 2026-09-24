import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_tournament_manager/shared/persistence/app_instance_lock.dart';

void main() {
  test(
    'a second process is blocked until the first releases its lock',
    () async {
      final directory = await Directory.systemTemp.createTemp('instance_lock_');
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/app.lock');
      final lock = await AppInstanceLock.acquire(file);
      Future<ProcessResult> probe() => Process.run('dart', [
        'test/support/storage_lock_probe.dart',
        file.path,
      ], runInShell: Platform.isWindows);
      try {
        final blocked = await probe().timeout(const Duration(seconds: 30));
        expect(
          blocked.exitCode,
          23,
          reason: '${blocked.stdout}\n${blocked.stderr}',
        );
      } finally {
        await lock.release();
      }
      final allowed = await probe().timeout(const Duration(seconds: 30));
      expect(
        allowed.exitCode,
        0,
        reason: '${allowed.stdout}\n${allowed.stderr}',
      );
    },
  );
}
