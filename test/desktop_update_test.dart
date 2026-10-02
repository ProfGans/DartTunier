import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:dart_tournament_manager/features/updates/data/desktop_bundle.dart';
import 'package:dart_tournament_manager/features/updates/application/desktop_update_launcher.dart';
import 'package:dart_tournament_manager/features/updates/domain/android_release.dart';
import 'package:dart_tournament_manager/features/updates/domain/update_platform.dart';

AndroidRelease release(UpdatePlatform platform) => AndroidRelease(
  version: '1.0.0',
  build: 12,
  url: Uri.parse(
    'https://github.com/ProfGans/DartTunier/releases/download/v1.0.0%2B12/${platform.assetName}',
  ),
  sha256: 'a' * 64,
  size: 100,
  notes: '',
  platform: platform,
);

void main() {
  late Directory temp;
  setUp(
    () async =>
        temp = await Directory.systemTemp.createTemp('desktop-update-test-'),
  );
  tearDown(() async => temp.delete(recursive: true));

  for (final platform in [UpdatePlatform.windows, UpdatePlatform.linux]) {
    Archive bundle({int build = 12}) {
      final archive = Archive();
      void add(String name, List<int> bytes) =>
          archive.addFile(ArchiveFile(name, bytes.length, bytes));
      add(
        'data/update-manifest.json',
        utf8.encode(
          jsonEncode({
            'schemaVersion': 1,
            'version': '1.0.0',
            'build': build,
            'platform': platform.name,
            'architecture': 'x64',
          }),
        ),
      );
      for (final name in [
        'data/icudtl.dat',
        platform == UpdatePlatform.windows
            ? 'dart_tournament_manager.exe'
            : 'dart_tournament_manager',
        platform == UpdatePlatform.windows
            ? 'flutter_windows.dll'
            : 'lib/libflutter_linux_gtk.so',
      ]) {
        add(name, [1, 2, 3]);
      }
      return archive;
    }

    Future<File> write(Archive archive) async {
      final bytes = platform == UpdatePlatform.windows
          ? ZipEncoder().encode(archive)
          : gzip.encode(TarEncoder().encode(archive));
      return File(p.join(temp.path, platform.assetName)).writeAsBytes(bytes);
    }

    test('${platform.name}: extracts and verifies matching bundle', () async {
      final destination = Directory(p.join(temp.path, 'bundle'));
      await DesktopBundle.extract(
        await write(bundle()),
        destination,
        release(platform),
      );
      expect(
        await File(p.join(destination.path, 'data/icudtl.dat')).readAsBytes(),
        [1, 2, 3],
      );
      await expectLater(
        DesktopBundle.extract(
          await write(bundle()),
          destination,
          release(platform),
        ),
        throwsStateError,
      );
    });
    test('${platform.name}: rejects manifest version mismatch', () async {
      await expectLater(
        DesktopBundle.extract(
          await write(bundle(build: 11)),
          Directory(p.join(temp.path, 'bundle')),
          release(platform),
        ),
        throwsFormatException,
      );
    });
    test(
      '${platform.name}: rejects path traversal without writing outside bundle',
      () async {
        final archive = bundle()..addFile(ArchiveFile('../escaped', 1, [1]));
        await expectLater(
          DesktopBundle.extract(
            await write(archive),
            Directory(p.join(temp.path, 'bundle')),
            release(platform),
          ),
          throwsFormatException,
        );
        expect(await File(p.join(temp.path, 'escaped')).exists(), isFalse);
      },
    );
    test('${platform.name}: rejects incomplete and damaged archives', () async {
      final incomplete = Archive()..addFile(ArchiveFile('readme', 1, [1]));
      await expectLater(
        DesktopBundle.extract(
          await write(incomplete),
          Directory(p.join(temp.path, 'incomplete')),
          release(platform),
        ),
        throwsFormatException,
      );
      final damaged = await File(
        p.join(temp.path, 'damaged'),
      ).writeAsBytes([1, 2, 3]);
      await expectLater(
        DesktopBundle.extract(
          damaged,
          Directory(p.join(temp.path, 'damaged-out')),
          release(platform),
        ),
        throwsA(anything),
      );
    });
    test(
      '${platform.name}: chooses only platform assets, beta requires opt-in',
      () {
        Map<String, dynamic> json(
          int build,
          UpdatePlatform target, {
          bool beta = false,
        }) => {
          'draft': false,
          'prerelease': beta,
          'tag_name': 'v1.0.0+$build',
          'assets': [
            {
              'name': target.assetName,
              'state': 'uploaded',
              'size': 100,
              'digest': 'sha256:${'a' * 64}',
              'browser_download_url': release(target).url.toString(),
            },
          ],
        };
        final releases = [
          json(10, platform),
          json(12, platform, beta: true),
          json(99, UpdatePlatform.android),
        ];
        expect(
          AndroidRelease.newest(releases, 9, platform: platform)!.build,
          10,
        );
        expect(
          AndroidRelease.newest(
            releases,
            9,
            platform: platform,
            includePrereleases: true,
          )!.build,
          12,
        );
        expect(
          AndroidRelease.newest(
            releases,
            12,
            platform: platform,
            includePrereleases: true,
          ),
          isNull,
        );
      },
    );
  }
  test('rejects dangerous cross-platform paths and device names', () {
    for (final name in [
      '../file',
      r'a\..\file',
      '/tmp/file',
      r'C:\file',
      'data/NUL.txt',
      'foo:bar',
      'name.',
    ]) {
      expect(() => DesktopBundle.safePath(name), throwsFormatException);
    }
    expect(DesktopBundle.safePath('./data/icudtl.dat'), 'data/icudtl.dat');
  });
  test('launcher paths cannot escape managed directory', () async {
    expect(await DesktopUpdateLauncher.target(temp, '../other'), isNull);
    expect(await DesktopUpdateLauncher.target(temp, 'build-12-123'), isNull);
    final executable = File(
      p.join(
        temp.path,
        'build-12-123',
        'bundle',
        DesktopUpdateLauncher.executableName(),
      ),
    );
    await executable.parent.create(recursive: true);
    await executable.writeAsString('fixture');
    expect(
      await DesktopUpdateLauncher.target(temp, 'build-12-123'),
      await executable.resolveSymbolicLinks(),
    );
  });
  test('restart scripts quote spaces, apostrophes and shell expansion', () {
    final windows = DesktopUpdateLauncher.windowsScript(
      r"C:\O'Brien\$app\dart.exe",
      'build-12-123',
      4321,
    );
    expect(windows, contains(r"'C:\O''Brien\$app\dart.exe'"));
    expect(windows, contains('WaitForExit(120000)'));
    final linux = DesktopUpdateLauncher.linuxScript(
      r"/home/O'Brien/$app/dart",
      'build-12-123',
      4321,
    );
    expect(linux, contains(r"'/home/O'\''Brien/$app/dart'"));
    expect(linux, contains('kill -0 4321'));
  });
}
