import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:dart_tournament_manager/shared/persistence/storage_access.dart';
import '../domain/remote_control_settings.dart';

class RemoteSettingsStorage {
  RemoteSettingsStorage({this.file});
  final File? file;
  Future<File> _target() async =>
      file ??
      File(
        '${(await getApplicationSupportDirectory()).path}${Platform.pathSeparator}remote_control.json',
      );
  Future<RemoteControlSettings> load() => StorageAccess.run(() async {
    final target = await _target();
    if (!await target.exists()) return const RemoteControlSettings();
    return RemoteControlSettings.fromJson(
      jsonDecode(await target.readAsString()) as Map<String, dynamic>,
    );
  });
  Future<void> save(RemoteControlSettings settings) => StorageAccess.run(
    () async {
      final target = await _target();
      await target.parent.create(recursive: true);
      if (await target.exists()) await target.copy('${target.path}.bak');
      final temporary = File('${target.path}.tmp');
      await temporary.writeAsString(jsonEncode(settings.toJson()), flush: true);
      await temporary.rename(target.path);
    },
  );
}
