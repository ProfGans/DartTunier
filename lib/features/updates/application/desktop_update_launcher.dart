import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Installs beside the original application. Old shortcuts forward only after
/// the new application completed bootstrap and acknowledged the new version.
class DesktopUpdateLauncher {
  static Future<Directory> root() async => Directory(
    p.join((await getApplicationSupportDirectory()).path, 'desktop_updates'),
  );
  static String executableName() => Platform.isWindows
      ? 'dart_tournament_manager.exe'
      : 'dart_tournament_manager';
  static bool validId(String id) =>
      RegExp(r'^build-[0-9]+-[0-9]+$').hasMatch(id);

  static Future<String?> target(Directory base, String id) async {
    if (!validId(id)) return null;
    final exe = File(p.join(base.path, id, 'bundle', executableName()));
    if (!await exe.exists()) return null;
    final resolved = await exe.resolveSymbolicLinks();
    if (!p.isWithin(await base.resolveSymbolicLinks(), resolved)) return null;
    return resolved;
  }

  static Future<void> forward(List<String> args) async {
    if (!(Platform.isWindows || Platform.isLinux) ||
        args.contains('--desktop-update-original') ||
        args.any((arg) => arg.startsWith('--desktop-update-activate='))) {
      return;
    }
    try {
      final base = await root();
      final pointer = File(p.join(base.path, 'active.json'));
      if (!await pointer.exists()) return;
      final saved = jsonDecode(await pointer.readAsString()) as Map;
      if (saved['schemaVersion'] != 1 ||
          saved['id'] is! String ||
          saved['build'] is! int) {
        return;
      }
      final installed = int.tryParse(
        (await PackageInfo.fromPlatform()).buildNumber,
      );
      if (installed == null || saved['build'] <= installed) return;
      final exe = await target(base, saved['id'] as String);
      if (exe == null || p.equals(exe, Platform.resolvedExecutable)) return;
      if (Platform.isLinux) {
        await restart(saved['id'] as String, forwardedArgs: args);
        exit(0);
      }
      await Process.start(
        exe,
        args,
        workingDirectory: p.dirname(exe),
        mode: ProcessStartMode.detached,
      );
      exit(0);
    } catch (_) {
      // The original remains usable when an update directory is removed.
    }
  }

  static Future<void> acknowledge(List<String> args) async {
    final markers = args
        .where((arg) => arg.startsWith('--desktop-update-activate='))
        .toList();
    if (markers.length != 1 || !(Platform.isWindows || Platform.isLinux)) {
      return;
    }
    final id = markers.single.split('=').last;
    final base = await root();
    final exe = await target(base, id);
    if (exe == null ||
        !p.equals(
          exe,
          await File(Platform.resolvedExecutable).resolveSymbolicLinks(),
        )) {
      return;
    }
    final data =
        jsonDecode(
              await File(
                p.join(p.dirname(exe), 'data', 'update-manifest.json'),
              ).readAsString(),
            )
            as Map;
    final package = await PackageInfo.fromPlatform();
    if (data['schemaVersion'] != 1 ||
        data['build'] != int.tryParse(package.buildNumber) ||
        data['version'] != package.version) {
      throw const FormatException(
        'Installierte Update-Version stimmt nicht mit dem Paket überein.',
      );
    }
    final active = File(p.join(base.path, 'active.json'));
    if (await active.exists()) {
      final previous = jsonDecode(await active.readAsString()) as Map;
      if (previous['schemaVersion'] == 1 &&
          previous['build'] is int &&
          previous['build'] > data['build']) {
        return;
      }
    }
    final temporary = File(p.join(base.path, 'active.json.new'));
    await temporary.writeAsString(
      jsonEncode({'schemaVersion': 1, 'id': id, 'build': data['build']}),
      flush: true,
    );
    await temporary.rename(p.join(base.path, 'active.json'));
  }

  static String windowsScript(String exe, String id, int parentPid) {
    String quote(String value) => "'${value.replaceAll("'", "''")}'";
    return '''\$ErrorActionPreference = 'Stop'
\$parentProcess = Get-Process -Id $parentPid -ErrorAction SilentlyContinue
if (\$null -ne \$parentProcess) { if (-not \$parentProcess.WaitForExit(120000)) { throw 'App wurde nicht beendet.' } }
Start-Process -FilePath ${quote(exe)} -WorkingDirectory ${quote(p.dirname(exe))} -ArgumentList '--desktop-update-activate=$id' -WindowStyle Normal
''';
  }

  static String linuxScript(
    String exe,
    String id,
    int parentPid, {
    List<String> forwardedArgs = const [],
  }) {
    String quote(String value) => "'${value.replaceAll("'", "'\\''")}'";
    return '''#!/bin/sh
set -eu
attempt=0
while kill -0 $parentPid 2>/dev/null; do
  attempt=\$((attempt + 1))
  [ "\$attempt" -le 120 ] || exit 1
  sleep 1
done
cd ${quote(p.dirname(exe))}
exec ${quote(exe)} ${forwardedArgs.map(quote).join(' ')} '--desktop-update-activate=$id'
''';
  }

  static Future<void> restart(
    String id, {
    List<String> forwardedArgs = const [],
  }) async {
    final base = await root();
    final exe = await target(base, id);
    if (exe == null) throw const FileSystemException('Update-Dateien fehlen.');
    final script = File(
      p.join(base.path, id, Platform.isWindows ? 'restart.ps1' : 'restart.sh'),
    );
    await script.writeAsString(
      Platform.isWindows
          ? windowsScript(exe, id, pid)
          : linuxScript(exe, id, pid, forwardedArgs: forwardedArgs),
      flush: true,
    );
    if (Platform.isWindows) {
      final shell = p.join(
        Platform.environment['SystemRoot'] ?? r'C:\Windows',
        'System32',
        'WindowsPowerShell',
        'v1.0',
        'powershell.exe',
      );
      final command = windowsScript(exe, id, pid);
      final encoded = base64Encode([
        for (final unit in command.codeUnits) ...[unit & 255, unit >> 8],
      ]);
      await Process.start(shell, [
        '-NoProfile',
        '-NonInteractive',
        '-WindowStyle',
        'Hidden',
        '-EncodedCommand',
        encoded,
      ], mode: ProcessStartMode.detached);
    } else {
      await Process.start('/bin/sh', [
        script.path,
      ], mode: ProcessStartMode.detached);
    }
  }
}
