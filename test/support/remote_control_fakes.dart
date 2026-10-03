import 'dart:async';
import 'dart:io';
import 'package:dart_tournament_manager/features/devices/domain/app_device.dart';
import 'package:dart_tournament_manager/features/remote_control/application/remote_host_controller.dart';
import 'package:dart_tournament_manager/features/remote_control/data/remote_account_repository.dart';
import 'package:dart_tournament_manager/features/remote_control/data/remote_settings_storage.dart';
import 'package:dart_tournament_manager/features/remote_control/domain/account_remote_device.dart';
import 'package:dart_tournament_manager/features/remote_control/domain/remote_control_settings.dart';

class MemoryRemoteSettings extends RemoteSettingsStorage {
  MemoryRemoteSettings([this.value = const RemoteControlSettings()]);
  RemoteControlSettings value;
  bool failSave = false;
  @override
  Future<RemoteControlSettings> load() async => value;
  @override
  Future<void> save(RemoteControlSettings settings) async {
    if (failSave) throw const FileSystemException('Speichern fehlgeschlagen');
    value = settings;
  }
}

class MemoryRemoteAccounts extends RemoteAccountRepository {
  String? owner = 'owner-a';
  final events = StreamController<String?>.broadcast(sync: true);
  final rows = <String, AccountRemoteDevice>{};
  bool failPublish = false;
  @override
  String? get userId => owner;
  @override
  Stream<String?> get accountChanges => events.stream;
  void changeAccount(String? id) { owner = id; events.add(id); }
  @override
  Future<void> publish(AppDevice device, List<String> addresses, String key) async {
    if (failPublish) throw StateError('Server nicht eingerichtet');
    rows['$owner:${device.id}'] = AccountRemoteDevice(device: device, addresses: addresses, key: key);
  }
  @override
  Future<List<AccountRemoteDevice>> load() async => owner == null ? [] :
    [for (final entry in rows.entries) if (entry.key.startsWith('$owner:')) entry.value];
  @override
  Future<void> revoke(String deviceId) async { rows.remove('$owner:$deviceId'); }
}

class LoopbackRemoteHost extends RemoteHostController {
  LoopbackRemoteHost({super.settingsStorage, super.accountRepository});
  @override
  Future<void> start({InternetAddress? bindAddress, int listenPort = RemoteHostController.port}) =>
    super.start(bindAddress: InternetAddress.loopbackIPv4, listenPort: 0);
}

const remoteTestDevice = AppDevice(id: 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa', name: 'Autoscoring-PC', platform: 'windows');
