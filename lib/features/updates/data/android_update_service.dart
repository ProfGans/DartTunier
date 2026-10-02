import '../application/app_update_service.dart';
import 'github_release_client.dart';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import '../../../shared/persistence/storage_access.dart';
import '../../backups/data/backup_service.dart';
import '../domain/android_release.dart';

class AndroidUpdateService extends AppUpdateService {
  @override
  bool get supported => Platform.isAndroid;
  static const _channel = MethodChannel('dartturnier/updates');
  @override
  Future<({String version, int build})> installed() async {
    final data = await _channel.invokeMapMethod<String, dynamic>('installed');
    return (version: data!['version'] as String, build: data['build'] as int);
  }

  @override
  Future<AndroidRelease?> check(
    int installedBuild, {
    bool includePrereleases = false,
  }) => GitHubReleaseClient().check(
    installedBuild,
    includePrereleases: includePrereleases,
  );

  @override
  Future<File> download(
    AndroidRelease release,
    void Function(double) progress,
  ) async => GitHubReleaseClient().download(
    release,
    progress,
    File('${(await getTemporaryDirectory()).path}/updates/update.apk'),
  );

  /// Android verifies package, version and signer before opening its installer.
  @override
  Future<bool> install() => StorageAccess.run(() async {
    final allowed = await _channel.invokeMethod<bool>('permission') ?? false;
    if (!allowed) return false;
    await _channel.invokeMethod<void>('validate');
    final backups = await BackupService.create();
    final bytes = await backups.exportBytes();
    await backups.backupDirectory.create(recursive: true);
    final backup = File(
      '${backups.backupDirectory.path}/before_update_${DateTime.now().microsecondsSinceEpoch}.dartbackup',
    );
    await backup.writeAsBytes(bytes, flush: true);
    await _channel.invokeMethod<void>('install');
    StorageAccess.requireRestart(
      'Die Android-Installation wurde geöffnet. '
      'Bitte starte die App danach neu. Sicherung des vorherigen Stands:\n${backup.path}',
    );
    return true;
  });
}
