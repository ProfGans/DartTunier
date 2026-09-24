import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import '../../../shared/persistence/storage_access.dart';
import '../../backups/data/backup_service.dart';
import '../domain/android_release.dart';

class AndroidUpdateService {
  static const _channel = MethodChannel('dartturnier/updates');
  Future<({String version, int build})> installed() async {
    final data = await _channel.invokeMapMethod<String, dynamic>('installed');
    return (version: data!['version'] as String, build: data['build'] as int);
  }

  Future<AndroidRelease?> check(int installedBuild) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15);
    try {
      final request = await client.getUrl(
        Uri.https(
          'api.github.com',
          '/repos/${AndroidRelease.repository}/releases',
          {'per_page': '100'},
        ),
      );
      request.headers.set('User-Agent', 'DartTournamentManager');
      request.headers.set('Accept', 'application/vnd.github+json');
      final response = await request.close().timeout(
        const Duration(seconds: 20),
      );
      if (response.statusCode != 200) {
        throw HttpException(
          'GitHub antwortet mit ${response.statusCode}. Bitte später erneut prüfen.',
        );
      }
      final bytes = <int>[];
      await for (final chunk in response.timeout(const Duration(seconds: 20))) {
        bytes.addAll(chunk);
        if (bytes.length > 4 * 1024 * 1024) {
          throw const FormatException('Release-Antwort zu groß.');
        }
      }
      final json = jsonDecode(utf8.decode(bytes));
      if (json is! List) {
        throw const FormatException('Ungültige Release-Antwort.');
      }
      return AndroidRelease.newest(json, installedBuild);
    } finally {
      client.close(force: true);
    }
  }

  Future<File> download(
    AndroidRelease release,
    void Function(double) progress,
  ) async {
    final directory = Directory(
      '${(await getTemporaryDirectory()).path}/updates',
    );
    await directory.create(recursive: true);
    final temporary = File('${directory.path}/update.apk.part');
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15);
    try {
      var uri = release.url;
      HttpClientResponse? response;
      for (var redirects = 0; redirects <= 5; redirects++) {
        if (uri.scheme != 'https' ||
            ![
              'github.com',
              'release-assets.githubusercontent.com',
              'objects.githubusercontent.com',
            ].contains(uri.host)) {
          throw const FormatException('Nicht erlaubter Download-Server.');
        }
        final request = await client.getUrl(uri);
        request.followRedirects = false;
        response = await request.close().timeout(const Duration(seconds: 30));
        if (!response.isRedirect) break;
        final location = response.headers.value(HttpHeaders.locationHeader);
        if (location == null) {
          throw const FormatException('Ungültige Weiterleitung.');
        }
        uri = uri.resolve(location);
        await response.drain<void>().timeout(const Duration(seconds: 15));
      }
      if (response?.statusCode != 200) {
        throw const HttpException('APK konnte nicht geladen werden.');
      }
      final output = await temporary.open(mode: FileMode.write);
      var count = 0;
      try {
        await for (final chunk in response!.timeout(
          const Duration(seconds: 30),
        )) {
          count += chunk.length;
          if (count > release.size) {
            throw const FormatException('APK-Größe stimmt nicht.');
          }
          await output.writeFrom(chunk);
          progress(count / release.size);
        }
        await output.flush();
      } finally {
        await output.close();
      }
      if (count != release.size ||
          (await sha256.bind(temporary.openRead()).first).toString() !=
              release.sha256) {
        throw const FormatException(
          'APK-Prüfsumme stimmt nicht. Installation abgebrochen.',
        );
      }
      return await temporary.rename('${directory.path}/update.apk');
    } finally {
      client.close(force: true);
      if (await temporary.exists()) await temporary.delete();
    }
  }

  /// Android verifies package, version and signer before opening its installer.
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
