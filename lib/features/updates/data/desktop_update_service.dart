import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import '../../../shared/persistence/storage_access.dart';
import '../../backups/data/backup_service.dart';
import '../application/app_update_service.dart';
import '../application/desktop_update_launcher.dart';
import '../domain/android_release.dart';
import '../domain/update_platform.dart';
import 'desktop_bundle.dart';
import 'github_release_client.dart';

class DesktopUpdateService extends AppUpdateService {
  UpdatePlatform get platform =>
      Platform.isWindows ? UpdatePlatform.windows : UpdatePlatform.linux;
  @override
  bool get supported =>
      Abi.current() == Abi.windowsX64 || Abi.current() == Abi.linuxX64;
  @override
  bool get isDesktop => true;
  @override
  String get platformLabel => platform.label;
  Directory? staged;
  AndroidRelease? pending;
  @override
  Future<({String version, int build})> installed() async {
    final info = await PackageInfo.fromPlatform();
    final build = int.tryParse(info.buildNumber);
    if (build == null || build < 1) {
      throw StateError(
        'Installierte Build-Nummer konnte nicht erkannt werden.',
      );
    }
    return (version: info.version, build: build);
  }

  @override
  Future<AndroidRelease?> check(
    int installedBuild, {
    bool includePrereleases = false,
  }) => GitHubReleaseClient().check(
    installedBuild,
    includePrereleases: includePrereleases,
    platform: platform,
  );
  @override
  Future<File> download(
    AndroidRelease release,
    void Function(double) progress,
  ) async {
    if (!supported ||
        release.platform != platform ||
        release.build <= (await installed()).build) {
      throw StateError('Unpassendes Desktop-Update.');
    }
    staged = null;
    pending = null;
    final base = await DesktopUpdateLauncher.root();
    await base.create(recursive: true);
    final directory = Directory(
      p.join(
        base.path,
        'build-${release.build}-${DateTime.now().microsecondsSinceEpoch}',
      ),
    );
    await directory.create();
    final file = await GitHubReleaseClient().download(
      release,
      progress,
      File(p.join(directory.path, platform.assetName)),
    );
    await Isolate.run(
      () => DesktopBundle.extract(
        file,
        Directory(p.join(directory.path, 'bundle')),
        release,
      ),
    );
    if (platform == UpdatePlatform.linux) {
      final result = await Process.run('/bin/chmod', [
        'u+x',
        p.join(directory.path, 'bundle', 'dart_tournament_manager'),
      ]);
      if (result.exitCode != 0) {
        throw const FileSystemException(
          'Startrecht konnte nicht gesetzt werden.',
        );
      }
    }
    staged = directory;
    pending = release;
    return file;
  }

  @override
  Future<bool> install() => StorageAccess.run(() async {
    if (staged == null || pending == null) {
      throw StateError('Zuerst das Update herunterladen.');
    }
    if (pending!.build <= (await installed()).build) {
      throw StateError('Keine neuere Version.');
    }
    await DesktopBundle.validate(
      Directory(p.join(staged!.path, 'bundle')),
      pending!,
    );
    final backups = await BackupService.create();
    final bytes = await backups.exportBytes();
    await backups.backupDirectory.create(recursive: true);
    final backup = File(
      p.join(
        backups.backupDirectory.path,
        'before_update_${DateTime.now().microsecondsSinceEpoch}.dartbackup',
      ),
    );
    await backup.writeAsBytes(bytes, flush: true);
    await DesktopUpdateLauncher.restart(p.basename(staged!.path));
    StorageAccess.requireRestart(
      'Desktop-Update wird gestartet. Datensicherung: ${backup.path}',
    );
    exit(0);
  });
}
