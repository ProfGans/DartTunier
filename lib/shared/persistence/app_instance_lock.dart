import 'dart:io';

/// Held until process exit. The OS releases the lock even after a crash.
/// Never delete the file: doing so can create two independently locked files.
class AppInstanceLock {
  AppInstanceLock._(this._handle);
  final RandomAccessFile _handle;

  static Future<AppInstanceLock> acquire(File file) async {
    await file.parent.create(recursive: true);
    final handle = await file.open(mode: FileMode.append);
    try {
      await handle.lock(FileLock.exclusive, 0, 1);
      return AppInstanceLock._(handle);
    } catch (_) {
      await handle.close();
      rethrow;
    }
  }

  Future<void> release() => _handle.close();
}
