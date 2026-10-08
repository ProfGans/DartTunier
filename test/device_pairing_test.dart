import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_tournament_manager/features/devices/data/board_display_client.dart';
import 'package:dart_tournament_manager/features/devices/data/board_display_server.dart';
import 'package:dart_tournament_manager/features/devices/data/device_link_auth.dart';
import 'package:dart_tournament_manager/features/devices/data/lan_device_discovery.dart';
import 'package:dart_tournament_manager/features/devices/domain/app_device.dart';
import 'package:dart_tournament_manager/features/devices/domain/board_display.dart';

void main() {
  const target = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  const source = 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
  test(
    'board start is authenticated and cleared when revoked or reassigned',
    () async {
      final server = BoardDisplayServer(
        port: 0,
        bindAddress: InternetAddress.loopbackIPv4,
      );
      addTearDown(server.dispose);
      final key = DeviceLinkAuth.newKey();
      await server.configure(deviceId: target, key: key, enabled: true);
      final client = BoardDisplayClient();
      Future<Map<String, dynamic>?> send(bool allowed, String id) =>
          client.send(
            address: '127.0.0.1',
            targetId: target,
            key: key,
            sourceId: source,
            port: server.localPort!,
            display: BoardDisplay(
              tournamentId: 'cup',
              tournamentName: 'Cup',
              board: 1,
              state: 'planned',
              matchId: id,
              allowDeviceStart: allowed,
            ),
          );
      await send(false, 'first');
      server.requestStart();
      expect(server.startPending, isFalse);
      await send(true, 'first');
      server.requestStart();
      expect(await send(true, 'first'), {'kind': 'start', 'matchId': 'first'});
      expect(await send(true, 'second'), isNull);
      expect(server.startPending, isFalse);
      server.requestStart();
      expect(await send(false, 'second'), isNull);
      expect(server.startPending, isFalse);
    },
  );
  test(
    'confirmed exchange derives a session key and reset revokes it',
    () async {
      final server = BoardDisplayServer(
        port: 0,
        bindAddress: InternetAddress.loopbackIPv4,
      );
      addTearDown(server.dispose);
      final original = DeviceLinkAuth.newKey();
      await server.configure(deviceId: target, key: original, enabled: true);
      final client = BoardDisplayClient();
      final key = await client.requestPairing(
        address: '127.0.0.1',
        targetId: target,
        name: 'Leitung',
        port: server.localPort!,
        onConfirmation: (code) {
          expect(server.display, isNull);
          expect(code, server.pairingCode);
          expect(code.length, 6);
          server.answerPairing(true);
        },
      );
      expect(key, isNot(original));
      expect(server.pairingName, isNull);
      Future<void> send() => client.send(
        address: '127.0.0.1',
        targetId: target,
        key: key,
        sourceId: source,
        port: server.localPort!,
        display: const BoardDisplay(
          tournamentId: 't',
          tournamentName: 'Test',
          board: 1,
          state: 'waiting',
        ),
      );
      await send();
      expect(server.display?.tournamentName, 'Test');
      await server.configure(
        deviceId: target,
        key: DeviceLinkAuth.newKey(),
        enabled: true,
      );
      await expectLater(send(), throwsA(isA<HttpException>()));
    },
  );
  test('denied pairing never authorizes display', () async {
    final server = BoardDisplayServer(
      port: 0,
      bindAddress: InternetAddress.loopbackIPv4,
    );
    addTearDown(server.dispose);
    await server.configure(
      deviceId: target,
      key: DeviceLinkAuth.newKey(),
      enabled: true,
    );
    await expectLater(
      BoardDisplayClient().requestPairing(
        address: '127.0.0.1',
        targetId: target,
        name: 'Leitung',
        port: server.localPort!,
        onConfirmation: (_) => server.answerPairing(false),
      ),
      throwsA(isA<HttpException>()),
    );
    expect(server.display, isNull);
    expect(server.pairingName, isNull);
  });
  test('periodic discovery recovery retains discovered peers', () async {
    final discovery = LanDeviceDiscovery(
      listenPort: 0,
      bindAddress: InternetAddress.loopbackIPv4,
      broadcast: false,
      recoveryInterval: const Duration(milliseconds: 100),
    );
    addTearDown(discovery.dispose);
    const settings = DeviceSettings(
      self: AppDevice(id: source, name: 'Leitung', platform: 'windows'),
    );
    await discovery.configure(settings, scanning: true);
    final sender = await RawDatagramSocket.bind(
      InternetAddress.loopbackIPv4,
      0,
    );
    addTearDown(sender.close);
    final found = Completer<void>();
    discovery.addListener(() {
      if (discovery.peers.any((peer) => peer.device.id == target) &&
          !found.isCompleted) {
        found.complete();
      }
    });
    sender.send(
      const DeviceDiscoveryMessage(
        'presence',
        AppDevice(id: target, name: 'Handy', platform: 'android'),
      ).encode(),
      InternetAddress.loopbackIPv4,
      discovery.localPort!,
    );
    await found.future.timeout(const Duration(seconds: 2));
    await Future<void>.delayed(const Duration(milliseconds: 350));
    expect(discovery.localPort, isNotNull);
    expect(
      discovery.peers
          .where((peer) => peer.device.id == target)
          .single
          .device
          .name,
      'Handy',
    );
    await discovery.configure(settings, scanning: false);
    await Future<void>.delayed(const Duration(milliseconds: 150));
    expect(discovery.localPort, isNull);
  });
}
