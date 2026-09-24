import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_tournament_manager/features/devices/domain/app_device.dart';
import 'package:dart_tournament_manager/features/devices/data/device_settings_storage.dart';
import 'package:dart_tournament_manager/features/devices/data/lan_device_discovery.dart';
import 'package:dart_tournament_manager/features/devices/application/devices_controller.dart';

const self = AppDevice(
  id: 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
  name: 'Board A',
  platform: 'windows',
);
const other = AppDevice(
  id: 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
  name: 'Board B',
  platform: 'windows',
);

void main() {
  test(
    'device identity and opt-in survive restart, unknown versions are rejected',
    () async {
      final directory = await Directory.systemTemp.createTemp('devices_test');
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/devices.json');
      final store = DeviceSettingsStorage(file: file);
      final initial = await store.load();
      expect(initial.enabled, isFalse);
      await store.save(initial.copyWith(enabled: true, savedDevices: [other]));
      final restarted = await DeviceSettingsStorage(file: file).load();
      expect(restarted.self.id, initial.self.id);
      expect(restarted.enabled, isTrue);
      expect(restarted.savedDevices.single.id, other.id);
      await file.writeAsString(jsonEncode({'schemaVersion': 999}));
      await expectLater(store.load(), throwsFormatException);
    },
  );

  test(
    'discovery rejects foreign, malformed, oversized and future packets',
    () {
      final valid = const DeviceDiscoveryMessage('presence', other).encode();
      expect(DeviceDiscoveryMessage.decode(valid)!.device.id, other.id);
      for (final bytes in [
        [255, 0],
        List.filled(1025, 32),
        utf8.encode('{}'),
        utf8.encode(
          utf8.decode(valid).replaceFirst('"version":1', '"version":2'),
        ),
        utf8.encode(utf8.decode(valid).replaceFirst('"presence"', '"execute"')),
      ]) {
        expect(DeviceDiscoveryMessage.decode(bytes), isNull);
      }
      final presence = DevicePresence(
        device: other,
        address: '127.0.0.1',
        seenAt: DateTime(2026),
      );
      expect(
        presence.isFresh(DateTime(2026).add(const Duration(seconds: 89))),
        isTrue,
      );
      expect(
        presence.isFresh(DateTime(2026).add(const Duration(seconds: 90))),
        isFalse,
      );
    },
  );

  test(
    'real UDP discovery responds only in device mode and removes departing peers',
    () async {
      final discovery = LanDeviceDiscovery(
        listenPort: 0,
        bindAddress: InternetAddress.loopbackIPv4,
        broadcast: false,
      );
      addTearDown(discovery.dispose);
      await discovery.configure(
        const DeviceSettings(self: self, enabled: true),
        scanning: true,
      );
      expect(discovery.error, isNull);
      final socket = await RawDatagramSocket.bind(
        InternetAddress.loopbackIPv4,
        0,
      );
      addTearDown(socket.close);
      final replies = <DeviceDiscoveryMessage>[];
      final response = Completer<void>();
      final subscription = socket.listen((event) {
        if (event == RawSocketEvent.read) {
          final datagram = socket.receive();
          if (datagram != null) {
            final message = DeviceDiscoveryMessage.decode(datagram.data);
            if (message != null) {
              replies.add(message);
              if (!response.isCompleted) response.complete();
            }
          }
        }
      });
      addTearDown(subscription.cancel);
      void send(String kind) => socket.send(
        DeviceDiscoveryMessage(kind, other).encode(),
        InternetAddress.loopbackIPv4,
        discovery.localPort!,
      );
      send('query');
      await response.future.timeout(const Duration(seconds: 2));
      expect(replies.single.device.id, self.id);
      final found = Completer<void>();
      discovery.addListener(() {
        if (discovery.peers.isNotEmpty && !found.isCompleted) found.complete();
      });
      send('presence');
      await found.future.timeout(const Duration(seconds: 2));
      expect(discovery.peers.single.address, '127.0.0.1');
      final removed = Completer<void>();
      discovery.addListener(() {
        if (discovery.peers.isEmpty && !removed.isCompleted) removed.complete();
      });
      send('goodbye');
      await removed.future.timeout(const Duration(seconds: 2));
      await discovery.configure(
        const DeviceSettings(self: self),
        scanning: true,
      );
      send('query');
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(replies, hasLength(1));
      await discovery.configure(
        const DeviceSettings(self: self),
        scanning: false,
      );
      expect(discovery.localPort, isNull);
    },
  );

  test(
    'adding a peer is idempotent and survives a controller restart',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'device_controller',
      );
      addTearDown(() => directory.delete(recursive: true));
      final storage = DeviceSettingsStorage(
        file: File('${directory.path}/devices.json'),
      );
      final controller = DevicesController(
        storage: storage,
        discovery: LanDeviceDiscovery(
          listenPort: 0,
          bindAddress: InternetAddress.loopbackIPv4,
          broadcast: false,
        ),
      );
      addTearDown(controller.dispose);
      await controller.initialize();
      await controller.remember(other);
      await controller.remember(other);
      expect((await storage.load()).savedDevices, hasLength(1));
      await controller.rename('Board links');
      await controller.setEnabled(true);
      final saved = await storage.load();
      expect(saved.self.name, 'Board links');
      expect(saved.enabled, isTrue);
      await controller.forget(other.id);
      expect((await storage.load()).savedDevices, isEmpty);
    },
  );
}
