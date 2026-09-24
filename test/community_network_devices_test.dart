import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_tournament_manager/features/devices/application/devices_controller.dart';
import 'package:dart_tournament_manager/features/devices/data/lan_device_discovery.dart';
import 'package:dart_tournament_manager/features/devices/domain/app_device.dart';
import 'package:dart_tournament_manager/features/devices/presentation/community_network_devices.dart';
import 'package:dart_tournament_manager/features/devices/presentation/devices_scope.dart';
import 'devices_page_test.dart' show MemorySettings, AccountDevices;

class LiveDiscovery extends LanDeviceDiscovery {
  bool scanning = false;
  List<DevicePresence> found = [];
  @override
  List<DevicePresence> get peers => found;
  @override
  Future<void> configure(
    DeviceSettings settings, {
    required bool scanning,
  }) async {
    this.scanning = scanning;
  }

  void discover() {
    found = [
      DevicePresence(
        device: const AppDevice(
          id: 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
          name: 'Android Handy',
          platform: 'android',
        ),
        address: '192.168.1.24',
        seenAt: DateTime.now(),
      ),
    ];
    notifyListeners();
  }
}

void main() {
  testWidgets(
    'community scans continuously and shows newly found devices without cloud reads',
    (tester) async {
      final discovery = LiveDiscovery();
      final account = AccountDevices();
      final controller = DevicesController(
        storage: MemorySettings(),
        discovery: discovery,
        accountRepository: account,
      );
      await controller.initialize();
      await tester.pumpWidget(
        DevicesScope(
          controller: controller,
          child: const MaterialApp(
            home: Scaffold(body: CommunityNetworkDevices()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(discovery.scanning, isTrue);
      expect(account.loads, 0);
      expect(find.textContaining('Suche läuft ·'), findsOneWidget);
      discovery.discover();
      await tester.pumpAndSettle();
      expect(find.text('Android Handy'), findsOneWidget);
      expect(find.textContaining('192.168.1.24'), findsOneWidget);
      expect(account.loads, 0);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      expect(discovery.scanning, isFalse);
      controller.dispose();
    },
  );
}
