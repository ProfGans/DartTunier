import '../../../shared/persistence/storage_access.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:path_provider/path_provider.dart';
import '../domain/app_device.dart';
import 'device_link_auth.dart';

class DeviceSettingsStorage {
  DeviceSettingsStorage({this.file});
  final File? file;
  Future<File> storageFile() => _target();

  Future<File> _target() async {
    if (file != null) return file!;
    final directory = await getApplicationSupportDirectory();
    return File('${directory.path}${Platform.pathSeparator}devices.json');
  }

  Future<DeviceSettings> load() async {
    return StorageAccess.run(() async {
      final target = await _target();
      if (await target.exists()) {
        final settings = DeviceSettings.fromJson(
          jsonDecode(await target.readAsString()) as Map<String, dynamic>,
        );
        if (settings.pairingKey == null) {
          final migrated = settings.copyWith(
            pairingKey: DeviceLinkAuth.newKey(),
          );
          await save(migrated);
          return migrated;
        }
        if (!DeviceLinkAuth.validKey(settings.pairingKey!)) {
          throw const FormatException('Ungültiger Kopplungsschlüssel');
        }
        return settings;
      }
      final random = Random.secure();
      final id = List.generate(
        16,
        (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
      ).join();
      final host = Platform.localHostname.trim();
      final settings = DeviceSettings(
        pairingKey: DeviceLinkAuth.newKey(),
        self: AppDevice(
          id: id,
          name: host.isEmpty
              ? 'Mein Gerät'
              : host.substring(0, min(80, host.length)),
          platform: Platform.operatingSystem,
        ),
      );
      await save(settings);
      return settings;
    });
  }

  Future<void> save(DeviceSettings settings) async {
    return StorageAccess.run(() async {
      final target = await _target();
      await target.parent.create(recursive: true);
      if (await target.exists()) {
        DeviceSettings.fromJson(
          jsonDecode(await target.readAsString()) as Map<String, dynamic>,
        );
        await target.copy('${target.path}.bak');
      }
      final temporary = File('${target.path}.tmp');
      await temporary.writeAsString(jsonEncode(settings.toJson()), flush: true);
      await temporary.rename(target.path);
    });
  }
}
