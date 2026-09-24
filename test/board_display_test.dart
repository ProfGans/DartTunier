import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_tournament_manager/features/devices/data/board_display_client.dart';
import 'package:dart_tournament_manager/features/devices/data/board_display_server.dart';
import 'package:dart_tournament_manager/features/devices/data/device_link_auth.dart';
import 'package:dart_tournament_manager/features/devices/data/device_settings_storage.dart';
import 'package:dart_tournament_manager/features/devices/application/board_display_projector.dart';
import 'package:dart_tournament_manager/features/devices/application/board_device_dispatcher.dart';
import 'package:dart_tournament_manager/features/devices/application/devices_controller.dart';
import 'package:dart_tournament_manager/features/devices/domain/app_device.dart';
import 'package:dart_tournament_manager/features/devices/domain/board_display.dart';
import 'package:dart_tournament_manager/features/tournaments/application/order_of_play/order_of_play_controller.dart';
import 'package:dart_tournament_manager/features/tournaments/domain/tournament_models.dart';

const receiverId = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const sourceId = 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
class MemoryDeviceSettings extends DeviceSettingsStorage {
  @override
  Future<DeviceSettings> load() async => const DeviceSettings(
    self: AppDevice(id: sourceId, name: 'Leitung', platform: 'windows'));
}

class CapturingClient extends BoardDisplayClient {
  final states = <String>[];
  Completer<void>? gate;
  @override
  Future<void> send({required String address, required String targetId,
    required String key, required String sourceId, required BoardDisplay display,
    int port = BoardDisplayServer.defaultPort}) async {
    final wait = gate; gate = null;
    await wait?.future;
    states.add(display.state);
  }
}
const display = BoardDisplay(
  tournamentId: 't1',
  tournamentName: 'Vereinsabend',
  board: 1,
  state: 'running',
  home: 'Anna',
  away: 'Ben',
);

void main() {
  test('disconnect and reconnect are serialized behind an active update', () async {
    final devices = DevicesController(storage: MemoryDeviceSettings());
    await devices.initialize();
    final tournament = CreatedTournament(name: 'Test', players: [], stages: [], runStages: []);
    final client = CapturingClient();
    final dispatcher = BoardDeviceDispatcher(devices: devices, tournament: tournament,
      activeStage: () => 0, client: client);
    final peer = DevicePresence(device: const AppDevice(id: receiverId, name: 'Board', platform: 'windows'),
      address: '127.0.0.1', seenAt: DateTime.now());
    final key = DeviceLinkAuth.newKey();
    await dispatcher.bind(1, peer, key);
    final gate = Completer<void>(); client.gate = gate;
    final update = dispatcher.publish();
    await Future<void>.delayed(Duration.zero);
    final disconnect = dispatcher.unbind(1);
    final reconnect = dispatcher.bind(1, peer, key);
    gate.complete();
    await Future.wait([update, disconnect, reconnect]);
    expect(client.states, ['waiting', 'waiting', 'released', 'waiting']);
    expect(dispatcher.connections[1]!.status, 'Verbunden');
    await dispatcher.unbind(1);
    dispatcher.dispose(); devices.dispose();
  });
  test(
    'board display follows the production schedule, results and tournament completion',
    () {
      final players = [
        for (var i = 1; i <= 4; i++) TournamentPlayer.generated(i),
      ];
      final matches = [
        GroupMatch(homePlayer: players[0], awayPlayer: players[1], round: 1),
        GroupMatch(homePlayer: players[2], awayPlayer: players[3], round: 1),
      ];
      final tournament = CreatedTournament(
        name: 'Test',
        players: players,
        stages: [],
        boardCount: 1,
        runStages: [
          GroupTournamentRunStage(
            name: 'Gruppe',
            groupPlayType: 'round_robin',
            qualificationPlan: null,
            tieBreakers: [],
            groups: [
              TournamentGroup(
                name: 'A',
                playType: 'round_robin',
                players: players,
                matches: matches,
              ),
            ],
          ),
        ],
      );
      const planner = OrderOfPlayController();
      const projector = BoardDisplayProjector();
      final first = planner.plan(tournament, 0).planned.first.entry.match;
      expect(projector.project(tournament, 0)[1]!.state, 'planned');
      expect(planner.start(tournament, 0, first, 1), isTrue);
      expect(projector.project(tournament, 0)[1]!.home, first.homePlayer!.name);
      expect(projector.project(tournament, 0)[1]!.state, 'running');
      first.homeLegs = 3;
      first.awayLegs = 1;
      planner.resultRecorded(first);
      final next = projector.project(tournament, 0)[1]!;
      expect(next.state, 'planned');
      expect(next.home, isNot(first.homePlayer!.name));
      tournament.completedStageIndexes.add(0);
      expect(projector.project(tournament, 0)[1]!.state, 'finished');
    },
  );

  test(
    'authenticated HTTP roundtrip rejects wrong keys, competing senders and revoked codes',
    () async {
      final key = DeviceLinkAuth.newKey();
      final server = BoardDisplayServer(
        port: 0,
        bindAddress: InternetAddress.loopbackIPv4,
      );
      addTearDown(server.dispose);
      await server.configure(deviceId: receiverId, key: key, enabled: true);
      expect(server.error, isNull);
      Future<void> send(String secret, {String sender = sourceId}) =>
          BoardDisplayClient().send(
            address: '127.0.0.1',
            targetId: receiverId,
            key: secret,
            sourceId: sender,
            display: display,
            port: server.localPort!,
          );
      await expectLater(
        send(DeviceLinkAuth.newKey()),
        throwsA(isA<HttpException>()),
      );
      expect(server.display, isNull);
      await send(key);
      expect(server.display!.home, 'Anna');
      expect(server.connected, isTrue);
      await expectLater(
        send(key, sender: 'cccccccccccccccccccccccccccccccc'),
        throwsA(isA<HttpException>()),
      );
      await server.configure(
        deviceId: receiverId,
        key: DeviceLinkAuth.newKey(),
        enabled: true,
      );
      await expectLater(send(key), throwsA(isA<HttpException>()));
      expect(server.display, isNull);
      await server.configure(deviceId: receiverId, key: key, enabled: false);
      expect(server.localPort, isNull);
    },
  );

  test('signed assignments cannot be replayed', () async {
    final key = DeviceLinkAuth.newKey();
    final server = BoardDisplayServer(
      port: 0,
      bindAddress: InternetAddress.loopbackIPv4,
    );
    addTearDown(server.dispose);
    await server.configure(deviceId: receiverId, key: key, enabled: true);
    final client = HttpClient();
    addTearDown(() => client.close(force: true));
    Uri url(String path) => Uri(
      scheme: 'http',
      host: '127.0.0.1',
      port: server.localPort,
      path: path,
    );
    final challenge = await (await client.getUrl(url('/challenge'))).close();
    final nonce =
        (jsonDecode(await utf8.decoder.bind(challenge).join()) as Map)['nonce']
            as String;
    final body = jsonEncode({
      'sourceId': sourceId,
      'display': display.toJson(),
    });
    Future<int> post() async {
      final request = await client.postUrl(url('/display'));
      request.headers.set('x-device-nonce', nonce);
      request.headers.set(
        'x-device-proof',
        DeviceLinkAuth.sign(key, 'display\n$nonce\n$body'),
      );
      request.write(body);
      final response = await request.close();
      await response.drain<void>();
      return response.statusCode;
    }

    expect(await post(), 200);
    expect(await post(), 401);
  });

  test(
    'schema one migrates without changing device identity or enabled mode',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'device_migration',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/devices.json');
      await file.writeAsString(
        jsonEncode({
          'schemaVersion': 1,
          'self': {'id': receiverId, 'name': 'Board', 'platform': 'windows'},
          'enabled': true,
          'savedDevices': [],
        }),
      );
      final store = DeviceSettingsStorage(file: file);
      final settings = await store.load();
      expect(settings.self.id, receiverId);
      expect(settings.enabled, isTrue);
      expect(DeviceLinkAuth.validKey(settings.pairingKey!), isTrue);
      expect((await store.load()).pairingKey, settings.pairingKey);
    },
  );
}
