import 'package:flutter_test/flutter_test.dart';
import 'package:dart_tournament_manager/features/devices/application/board_device_dispatcher.dart';
import 'package:dart_tournament_manager/features/devices/application/devices_controller.dart';
import 'package:dart_tournament_manager/features/devices/data/lan_device_discovery.dart';
import 'package:dart_tournament_manager/features/devices/data/device_link_auth.dart';
import 'package:dart_tournament_manager/features/devices/data/board_display_client.dart';
import 'package:dart_tournament_manager/features/devices/domain/app_device.dart';
import 'package:dart_tournament_manager/features/devices/domain/board_display.dart';
import 'package:dart_tournament_manager/features/communities/domain/community_permissions.dart';
import 'community_tournament_elo_test.dart' show eloTournament;

class UngroupedDiscovery extends LanDeviceDiscovery {
  final peer = DevicePresence(
    device: const AppDevice(
      id: 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      name: 'Android ohne Gruppe',
      platform: 'android',
    ),
    address: '192.168.1.5',
    seenAt: DateTime.now(),
  );
  @override
  List<DevicePresence> get peers => [peer];
}

class TestDevices extends DevicesController {
  TestDevices(UngroupedDiscovery discovery) : super(discovery: discovery) {
    settings = const DeviceSettings(
      self: AppDevice(
        id: 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
        name: 'Windows',
        platform: 'windows',
      ),
    );
  }
  @override
  Future<void> openPage({bool loadAccount = true}) async {}
  @override
  void closePage() {}
}

class TestDisplayClient extends BoardDisplayClient {
  final sent = <BoardDisplay>[];
  @override
  Future<Map<String, dynamic>?> send({
    required String address,
    required String targetId,
    required String key,
    required String sourceId,
    required BoardDisplay display,
    int port = 45874,
  }) async {
    sent.add(display);
    return null;
  }
}

void main() {
  test(
    'community board accepts ungrouped LAN device and retains authorization',
    () async {
      final discovery = UngroupedDiscovery();
      final devices = TestDevices(discovery);
      final client = TestDisplayClient();
      final permissions = <CommunityPermission>[];
      var allowed = true;
      final dispatcher = BoardDeviceDispatcher(
        devices: devices,
        tournament: eloTournament(),
        activeStage: () => 0,
        client: client,
        authorize: (communityId, permission) async {
          expect(communityId, 'community');
          permissions.add(permission);
          if (!allowed) throw StateError('permission revoked');
        },
      );
      addTearDown(() {
        dispatcher.dispose();
        devices.dispose();
      });
      await dispatcher.start();
      expect(dispatcher.availablePeers.single, discovery.peer);
      await dispatcher.bind(1, discovery.peer, DeviceLinkAuth.newKey());
      expect(dispatcher.connections[1]!.device.id, discovery.peer.device.id);
      expect(client.sent, isNotEmpty);
      expect(permissions, [
        CommunityPermission.assignDevices,
        CommunityPermission.assignDevices,
      ]);
      await expectLater(
        dispatcher.bind(1, discovery.peer, 'invalid'),
        throwsFormatException,
      );
      await dispatcher.unbind(1);
      allowed = false;
      await expectLater(
        dispatcher.bind(1, discovery.peer, DeviceLinkAuth.newKey()),
        throwsStateError,
      );
      expect(dispatcher.connections, isEmpty);
    },
  );
}
