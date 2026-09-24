import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_tournament_manager/features/devices/application/devices_controller.dart';
import 'package:dart_tournament_manager/features/devices/data/device_account_repository.dart';
import 'package:dart_tournament_manager/features/devices/data/device_settings_storage.dart';
import 'package:dart_tournament_manager/features/devices/data/lan_device_discovery.dart';
import 'package:dart_tournament_manager/features/devices/domain/app_device.dart';
import 'package:dart_tournament_manager/features/devices/presentation/devices_page.dart';
import 'package:dart_tournament_manager/features/devices/presentation/devices_scope.dart';

class MemorySettings extends DeviceSettingsStorage {
  DeviceSettings value = const DeviceSettings(
    self: AppDevice(
      id: 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      name: 'Board links',
      platform: 'windows',
    ),
  );
  @override
  Future<DeviceSettings> load() async => value;
  @override
  Future<void> save(DeviceSettings settings) async {
    value = settings;
  }
}

class LocalDiscovery extends LanDeviceDiscovery {
  bool visible = false;
  @override
  Future<void> configure(
    DeviceSettings settings, {
    required bool scanning,
  }) async {
    visible = settings.enabled;
  }
}

class AccountDevices extends DeviceAccountRepository {
  final registered = <AppDevice>[];
  int loads = 0;
  @override
  String? get userId => 'account';
  @override
  Future<List<AppDevice>> load() async {
    loads++;
    return [...registered];
  }

  @override
  Future<void> register(AppDevice device) async {
    registered.add(device);
  }
}

void main() {
  testWidgets(
    'device mode is opt-in, persisted and account registration is explicit',
    (tester) async {
      final storage = MemorySettings();
      final discovery = LocalDiscovery();
      final account = AccountDevices();
      final controller = DevicesController(
        storage: storage,
        discovery: discovery,
        accountRepository: account,
      );
      await controller.initialize();
      expect(account.loads, 0);
      expect(account.registered, isEmpty);
      await tester.pumpWidget(
        DevicesScope(
          controller: controller,
          child: const MaterialApp(home: DevicesPage()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Board links'), findsOneWidget);
      expect(discovery.visible, isFalse);
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(storage.value.enabled, isTrue);
      expect(discovery.visible, isTrue);
      expect(account.registered, isEmpty);
      await tester.scrollUntilVisible(
        find.text('Diesen Computer dem Account hinzufügen'),
        150,
      );
      await tester.tap(find.text('Diesen Computer dem Account hinzufügen'));
      await tester.pumpAndSettle();
      expect(account.registered.single.name, 'Board links');
      expect(find.text('Registrierung aktualisieren'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      expect(discovery.visible, isTrue);
      controller.dispose();
    },
  );
}
