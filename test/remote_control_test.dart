import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_tournament_manager/features/devices/data/device_link_auth.dart';
import 'package:dart_tournament_manager/features/remote_control/data/remote_channel.dart';
import 'package:dart_tournament_manager/features/remote_control/domain/remote_pairing_code.dart';
import 'package:dart_tournament_manager/features/remote_control/application/remote_host_controller.dart';
import 'package:dart_tournament_manager/features/remote_control/application/remote_client_controller.dart';

Future<void> until(bool Function() predicate) async {
  final deadline = DateTime.now().add(const Duration(seconds: 5));
  while (!predicate()) {
    if (DateTime.now().isAfter(deadline)) throw TimeoutException('Zustand nicht erreicht');
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}

void main() {
  test('encrypted channel rejects replay, tampering and another session', () async {
    final key = DeviceLinkAuth.newKey();
    final challenge = DeviceLinkAuth.newKey();
    final host = RemoteChannel(key, challenge, host: true);
    final client = RemoteChannel(key, challenge, host: false);
    final packet = await host.encode({'type': 'text', 'text': 'Geheim'});
    expect(packet, isNot(contains('Geheim')));
    expect((await client.decode(packet))['text'], 'Geheim');
    await expectLater(client.decode(packet), throwsFormatException);
    final other = RemoteChannel(key, DeviceLinkAuth.newKey(), host: false);
    await expectLater(other.decode(packet), throwsA(anything));
    final next = await host.encode({'type': 'frame'});
    final envelope = jsonDecode(next) as Map<String, dynamic>;
    final bytes = base64Decode(envelope['data'] as String);
    bytes[0] ^= 1;
    envelope['data'] = base64Encode(bytes);
    await expectLater(client.decode(jsonEncode(envelope)), throwsA(anything));
    expect((await client.decode(next))['type'], 'frame');
    expect((await host.decode(await client.encode({'type': 'back'})))['type'], 'back');
  });

  test('pairing QR round trip and invalid invitations', () {
    final code = RemotePairingCode('192.168.1.20', DeviceLinkAuth.newKey());
    expect(RemotePairingCode.parse(code.encode())?.key, code.key);
    expect(RemotePairingCode.parse(code.encode())?.address, code.address);
    expect(RemotePairingCode.parse('https://example.org'), isNull);
    expect(RemotePairingCode.parse(code.encode().replaceFirst('version=1', 'version=2')), isNull);
    expect(RemotePairingCode.parse(RemotePairingCode('abc/def', code.key).encode()), isNull);
  });

  test('host streams current state, accepts ordered inputs, reconnects and revokes', () async {
    final host = RemoteHostController();
    final client = RemoteClientController();
    addTearDown(host.dispose);
    addTearDown(client.dispose);
    var captures = 0;
    final inputs = <String>[];
    host.onInput = (message) => inputs.add(message['type'] as String);
    host.capture = () async => {
      'type': 'frame', 'width': 800, 'height': 600, 'viewport': 3, 'editor': 2,
      'image': base64Encode([++captures]), 'editingText': 'Spieler', 'obscureText': false,
    };
    await host.start(bindAddress: InternetAddress.loopbackIPv4, listenPort: 0);
    expect(host.error, isNull);
    final key = host.pairingKey!;
    final run = client.connect('127.0.0.1', key, port: host.localPort!);
    await until(() => client.image != null);
    expect(host.connected, isTrue);
    expect(client.viewport, 3);
    expect(client.editingText, 'Spieler');
    await client.send({'type': 'down', 'viewport': 3, 'pointer': 0, 'x': .5, 'y': .5});
    await client.send({'type': 'up', 'viewport': 3, 'pointer': 0, 'x': .5, 'y': .5});
    await until(() => inputs.contains('up'));
    expect(inputs.where((type) => type != 'cancel').toList(), ['down', 'up']);
    await until(() => captures >= 2);
    await client.disconnect();
    await run;
    await until(() => !host.connected);
    expect(inputs.last, 'cancel');
    final reconnect = client.connect('127.0.0.1', key, port: host.localPort!);
    await until(() => client.image != null);
    await host.stop();
    await reconnect;
    expect(client.connected, isFalse);
    expect(host.pairingKey, isNull);
    await host.start(bindAddress: InternetAddress.loopbackIPv4, listenPort: 0);
    expect(host.pairingKey, isNot(key));
    await client.connect('127.0.0.1', key, port: host.localPort!);
    expect(client.error, isNotNull);
    expect(host.connected, isFalse);
    await host.stop();
  });

  test('wrong key and competing controller do not gain access', () async {
    final host = RemoteHostController();
    final client = RemoteClientController();
    final competitor = RemoteClientController();
    addTearDown(host.dispose); addTearDown(client.dispose); addTearDown(competitor.dispose);
    await host.start(bindAddress: InternetAddress.loopbackIPv4, listenPort: 0);
    await competitor.connect('127.0.0.1', DeviceLinkAuth.newKey(), port: host.localPort!);
    expect(host.connected, isFalse);
    final run = client.connect('127.0.0.1', host.pairingKey!, port: host.localPort!);
    await until(() => client.connected);
    await competitor.connect('127.0.0.1', host.pairingKey!, port: host.localPort!);
    expect(competitor.connected, isFalse);
    expect(client.connected, isTrue);
    await client.disconnect(); await run; await host.stop();
  });

  test('stop during start never leaves a hidden server', () async {
    final host = RemoteHostController();
    addTearDown(host.dispose);
    final starting = host.start(bindAddress: InternetAddress.loopbackIPv4, listenPort: 0);
    await host.stop(); await starting;
    expect(host.enabled, isFalse);
    expect(host.starting, isFalse);
    expect(host.pairingKey, isNull);
  });
}
