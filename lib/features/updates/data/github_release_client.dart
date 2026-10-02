import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import '../domain/android_release.dart';
import '../domain/update_platform.dart';

class GitHubReleaseClient {
  Future<AndroidRelease?> check(
    int installedBuild, {
    bool includePrereleases = false,
    UpdatePlatform platform = UpdatePlatform.android,
  }) async {
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
      return AndroidRelease.newest(
        json,
        installedBuild,
        includePrereleases: includePrereleases,
        platform: platform,
      );
    } finally {
      client.close(force: true);
    }
  }

  Future<File> download(
    AndroidRelease release,
    void Function(double) progress,
    File destination,
  ) async {
    await destination.parent.create(recursive: true);
    final temporary = File('${destination.path}.part');
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
        throw const HttpException('Update konnte nicht geladen werden.');
      }
      final output = await temporary.open(mode: FileMode.write);
      var count = 0;
      try {
        await for (final chunk in response!.timeout(
          const Duration(seconds: 30),
        )) {
          count += chunk.length;
          if (count > release.size) {
            throw const FormatException('Paket-Größe stimmt nicht.');
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
          'Paket-Prüfsumme stimmt nicht. Installation abgebrochen.',
        );
      }
      return await temporary.rename(destination.path);
    } finally {
      client.close(force: true);
      if (await temporary.exists()) await temporary.delete();
    }
  }
}
