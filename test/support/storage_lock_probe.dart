import 'dart:io';
import 'package:dart_tournament_manager/shared/persistence/app_instance_lock.dart';

Future<void> main(List<String> args) async {
  try {
    final lock = await AppInstanceLock.acquire(File(args.single));
    await lock.release();
    exitCode = 0;
  } on FileSystemException {
    exitCode = 23;
  }
}
