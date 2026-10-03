import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_tournament_manager/features/remote_control/application/remote_client_controller.dart';
import 'package:dart_tournament_manager/features/remote_control/data/remote_settings_storage.dart';
import 'package:dart_tournament_manager/features/remote_control/domain/remote_control_settings.dart';
import 'support/remote_control_fakes.dart';

Future<void> until(bool Function() predicate) async {
  final deadline = DateTime.now().add(const Duration(seconds: 5));
  while (!predicate()) {
    if (DateTime.now().isAfter(deadline)) throw TimeoutException('Zustand nicht erreicht');
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}

void main() {
  test('versioned settings default to no confirmation and survive restart', () async {
    final root = await Directory.systemTemp.createTemp('remote_settings_');
    addTearDown(() => root.delete(recursive: true));
    final storage = RemoteSettingsStorage(file: File('${root.path}/remote_control.json'));
    expect((await storage.load()).requireConfirmation, isFalse);
    await storage.save(const RemoteControlSettings(enabled: true, requireConfirmation: true));
    final loaded = await RemoteSettingsStorage(file: storage.file).load();
    expect(loaded.enabled, isTrue); expect(loaded.requireConfirmation, isTrue);
    await storage.save(loaded.copyWith(requireConfirmation: false));
    expect((await storage.load()).requireConfirmation, isFalse);
    expect(await File('${storage.file!.path}.bak').exists(), isTrue);
    expect(() => RemoteControlSettings.fromJson({'schemaVersion': 2, 'enabled': true, 'requireConfirmation': false}), throwsFormatException);
  });

  test('account proof connects without confirmation or a QR key and logout revokes it', () async {
    final accounts = MemoryRemoteAccounts();
    final settings = MemoryRemoteSettings(const RemoteControlSettings(enabled: true));
    final host = LoopbackRemoteHost(settingsStorage: settings, accountRepository: accounts);
    final client = RemoteClientController();
    addTearDown(host.dispose); addTearDown(client.dispose); addTearDown(accounts.events.close);
    await host.initialize(device: remoteTestDevice);
    expect(host.enabled, isTrue);
    final proof = (await accounts.find(remoteTestDevice.id)).key;
    expect(proof, isNot(host.pairingKey));
    final session = client.connect('127.0.0.1', proof, port: host.localPort!, mode: 'account');
    await until(() => client.connected);
    expect(host.pendingName, isNull);
    accounts.changeAccount(null);
    await session;
    expect(client.connected, isFalse);
    await client.connect('127.0.0.1', proof, port: host.localPort!, mode: 'account');
    expect(client.connected, isFalse);
    await host.stop();
  });

  test('confirmation blocks input until accepted; rejection and cancellation release the host', () async {
    final accounts = MemoryRemoteAccounts();
    final settings = MemoryRemoteSettings(const RemoteControlSettings(requireConfirmation: true));
    final host = LoopbackRemoteHost(settingsStorage: settings, accountRepository: accounts);
    final client = RemoteClientController();
    addTearDown(host.dispose); addTearDown(client.dispose); addTearDown(accounts.events.close);
    await host.initialize(device: remoteTestDevice); await host.start();
    final proof = (await accounts.find(remoteTestDevice.id)).key;
    var inputs = 0;
    host.onInput = (message) { if (message['type'] != 'cancel') inputs++; };
    Future<void> connect() => client.connect('127.0.0.1', proof, port: host.localPort!, mode: 'account', name: 'Mein Handy');
    var session = connect();
    await until(() => client.awaitingConfirmation);
    expect(host.pendingName, 'Mein Handy'); expect(host.connected, isFalse);
    await client.send({'type': 'back'}); expect(inputs, 0);
    host.answerConfirmation(true);
    await until(() => client.connected);
    await client.send({'type': 'back'}); await until(() => inputs == 1);
    await client.disconnect(); await session; await until(() => !host.connected);
    session = connect(); await until(() => client.awaitingConfirmation);
    host.answerConfirmation(false); await session;
    expect(client.error, contains('abgelehnt')); expect(host.connected, isFalse);
    session = connect(); await until(() => client.awaitingConfirmation);
    await client.disconnect(); await session;
    await until(() => host.pendingName == null);
    session = connect(); await until(() => client.awaitingConfirmation);
    await host.setRequireConfirmation(false);
    await until(() => client.connected);
    expect(settings.value.requireConfirmation, isFalse);
    await client.disconnect(); await session; await host.stop();
  });

  test('QR authentication cannot bypass enabled confirmation and account mode requires account proof', () async {
    final accounts = MemoryRemoteAccounts();
    final settings = MemoryRemoteSettings(const RemoteControlSettings(requireConfirmation: true));
    final host = LoopbackRemoteHost(settingsStorage: settings, accountRepository: accounts);
    final client = RemoteClientController();
    addTearDown(host.dispose); addTearDown(client.dispose); addTearDown(accounts.events.close);
    await host.initialize(device: remoteTestDevice); await host.start();
    await client.connect('127.0.0.1', host.pairingKey!, port: host.localPort!, mode: 'account');
    expect(client.connected, isFalse); expect(host.pendingName, isNull);
    final session = client.connect('127.0.0.1', host.pairingKey!, port: host.localPort!, mode: 'code');
    await until(() => client.awaitingConfirmation);
    host.answerConfirmation(true); await until(() => client.connected);
    await client.disconnect(); await session; await host.stop();
  });

  test('failed policy save preserves confirmation and stopped access stays revoked', () async {
    final accounts = MemoryRemoteAccounts();
    final settings = MemoryRemoteSettings(const RemoteControlSettings(requireConfirmation: true));
    final host = LoopbackRemoteHost(settingsStorage: settings, accountRepository: accounts);
    addTearDown(host.dispose); addTearDown(accounts.events.close);
    await host.initialize(device: remoteTestDevice);
    settings.failSave = true;
    await host.setRequireConfirmation(false);
    expect(host.requireConfirmation, isTrue); expect(host.error, isNotNull);
    settings.failSave = false;
    await host.setEnabled(true);
    expect(host.enabled, isTrue); expect(settings.value.enabled, isTrue);
    expect((await accounts.load()).length, 1);
    await host.setEnabled(false);
    expect(host.enabled, isFalse); expect(settings.value.enabled, isFalse);
    expect(await accounts.load(), isEmpty);
  });
}
