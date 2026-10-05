import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_tournament_manager/features/remote_control/application/remote_client_controller.dart';
import 'package:dart_tournament_manager/features/remote_control/application/remote_scorer_client.dart';
import 'package:dart_tournament_manager/features/remote_control/application/remote_scorer_host.dart';
import 'package:dart_tournament_manager/features/scorer/application/scorer_controller.dart';
import 'package:dart_tournament_manager/features/scorer/data/scorer_draft_storage.dart';
import 'package:dart_tournament_manager/features/scorer/domain/scorer_settings.dart';
import 'package:dart_tournament_manager/features/scorer/domain/x01/x01_rules.dart';
import 'support/remote_control_fakes.dart';

ScorerSettings remoteTestSettings({int score = 501}) => ScorerSettings(
  startScore: score,
  participants: const [
    ScorerParticipant('Hauptgerät'),
    ScorerParticipant('Fernbedienung'),
  ],
);

Map<String, dynamic> command(
  RemoteScorerHost host,
  String id,
  String action, [
  Map<String, dynamic> values = const {},
]) => {
  'version': 1,
  'commandId': id,
  'sessionId': host.snapshot()['sessionId'],
  'revision': host.revision,
  'action': action,
  ...values,
};

Future<void> eventually(bool Function() predicate) async {
  for (var i = 0; i < 150; i++) {
    if (predicate()) return;
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
  expect(predicate(), isTrue);
}

void main() {
  test(
    'authoritative commands, duplicate suppression, stale and foreign session rejection',
    () async {
      final host = RemoteScorerHost(),
          c = ScorerController(remoteTestSettings());
      host.attach(c, 'one');
      final score = command(host, 'a', 'score', {'points': 60});
      expect((await host.execute(score))['error'], isNull);
      expect(c.scores, [441, 501]);
      expect((await host.execute(score))['error'], isNull);
      expect(c.exportActions(), hasLength(1));
      expect(
        (await host.execute({...score, 'commandId': 'b'}))['error'],
        isNotNull,
      );
      expect(
        (await host.execute({...score, 'commandId': 'b'}))['error'],
        isNotNull,
      );
      expect(
        (await host.execute({
          ...command(host, 'c', 'undo'),
          'sessionId': 'old',
        }))['error'],
        isNotNull,
      );
      expect((await host.execute(command(host, 'd', 'undo')))['error'], isNull);
      expect(c.scores, [501, 501]);
      expect(
        (await host.execute(
          command(host, 'e', 'score', {'points': 999}),
        ))['error'],
        isNotNull,
      );
      host.detach(c);
      host.dispose();
      c.dispose();
    },
  );

  test(
    'phone remains unchanged until acknowledgement; host darts and undo propagate back',
    () async {
      final host = RemoteScorerHost(),
          c = ScorerController(remoteTestSettings());
      final phone = RemoteScorerClient();
      host.attach(c, 'camera');
      phone.receive(host.snapshot());
      final delivery = Completer<void>();
      phone.send = (m) async {
        await delivery.future;
        phone.receive(await host.execute(m));
      };
      final pending = phone.command('score', values: {'points': 60});
      expect(phone.pending, isTrue);
      expect(phone.controller!.scores, [501, 501]);
      expect(await phone.command('score', values: {'points': 60}), isFalse);
      delivery.complete();
      expect(await pending, isTrue);
      expect(phone.controller!.scores, c.scores);
      c.throwDart(
        const X01Rules().buildAllThrows().firstWhere((d) => d.label == 'T20'),
      );
      phone.receive(host.snapshot());
      expect(phone.controller!.remaining, 441);
      expect(phone.controller!.exportActions(), c.exportActions());
      c.undo();
      phone.receive(host.snapshot());
      expect(phone.controller!.remaining, 501);
      expect(phone.controller!.hits, hasLength(c.hits.length));
      phone.disconnect();
      expect(await phone.command('undo'), isFalse);
      phone.dispose();
      host.dispose();
      c.dispose();
    },
  );

  test(
    'checkout returns winner, legs and statistics and undo reopens the match',
    () async {
      final host = RemoteScorerHost(),
          c = ScorerController(
            ScorerSettings(
              startScore: 40,
              bestOfLegs: 1,
              participants: const [
                ScorerParticipant('A'),
                ScorerParticipant('B'),
              ],
            ),
          );
      final phone = RemoteScorerClient();
      host.attach(c, 'checkout');
      phone.receive(host.snapshot());
      phone.send = (m) async => phone.receive(await host.execute(m));
      expect(
        await phone.command(
          'score',
          values: {'points': 40, 'darts': 1, 'attempts': 1},
        ),
        isTrue,
      );
      expect(c.isComplete, isTrue);
      expect(phone.controller!.winner, c.winner);
      expect(phone.controller!.legs, c.legs);
      expect(
        phone.controller!.statisticsVisits.single.points,
        c.statisticsVisits.single.points,
      );
      expect(await phone.command('undo'), isTrue);
      expect(phone.controller!.isComplete, isFalse);
      expect(
        await phone.command(
          'score',
          values: {'points': 40, 'darts': 1, 'attempts': 1},
        ),
        isTrue,
      );
      host.detach(c);
      phone.receive(host.snapshot());
      expect(phone.controller!.isComplete, isTrue);
      expect(phone.state!['resultFinalized'], isTrue);
      phone.dispose();
      host.dispose();
      c.dispose();
    },
  );

  test(
    'remote start and camera actions execute on host; camera blocks manual input',
    () async {
      final host = RemoteScorerHost();
      ScorerController? c;
      host.startMatch = (settings) async {
        c = ScorerController(settings);
        host.attach(c!, 'new');
      };
      final phone = RemoteScorerClient()..receive(host.snapshot());
      phone.send = (m) async => phone.receive(await host.execute(m));
      expect(
        await phone.command(
          'start',
          values: {
            'settings': ScorerDraftStorage.encodeSettings(remoteTestSettings()),
          },
        ),
        isTrue,
      );
      expect(c, isNotNull);
      expect(phone.controller, isNotNull);
      host.cameraState(available: true, open: false, pending: false);
      phone.receive(host.snapshot());
      final cameraCommands = <String>[];
      host.cameraAction = (a) async {
        cameraCommands.add(a);
        host.cameraState(
          available: true,
          open: a != 'cameraClose',
          pending: a == 'cameraOpen',
        );
      };
      expect(await phone.command('cameraOpen'), isTrue);
      expect(phone.state!['cameraPending'], isTrue);
      expect(await phone.command('score', values: {'points': 60}), isFalse);
      expect(c!.scores, [501, 501]);
      expect(await phone.command('cameraConfirm'), isTrue);
      expect(await phone.command('cameraClose'), isTrue);
      expect(cameraCommands, ['cameraOpen', 'cameraConfirm', 'cameraClose']);
      expect(await phone.command('score', values: {'points': 60}), isTrue);
      host.detach(c!);
      phone.receive(host.snapshot());
      expect(phone.controller, isNull);
      phone.dispose();
      host.dispose();
      c!.dispose();
    },
  );

  test(
    'encrypted LAN action mode sends no images and reconnect restores authoritative state',
    () async {
      final host = LoopbackRemoteHost(
        settingsStorage: MemoryRemoteSettings(),
        accountRepository: MemoryRemoteAccounts(),
      );
      final c = ScorerController(remoteTestSettings());
      await host.initialize(device: remoteTestDevice);
      host.scorer.attach(c, 'lan');
      var captures = 0, rawInputs = 0;
      host.capture = () async {
        captures++;
        return null;
      };
      host.onInput = (_) => rawInputs++;
      await host.start();
      final client = RemoteClientController();
      final connection = client.connect(
        '127.0.0.1',
        host.pairingKey!,
        port: host.localPort!,
        actions: true,
      );
      await eventually(() => client.scorer.ready);
      expect(client.image, isNull);
      expect(captures, 0);
      expect(
        await client.scorer.command('score', values: {'points': 60}),
        isTrue,
      );
      expect(c.scores, [441, 501]);
      expect(client.scorer.controller!.scores, c.scores);
      await client.send({'type': 'down', 'x': .5, 'y': .5});
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(rawInputs, 0);
      await client.disconnect();
      await connection;
      await eventually(() => !host.connected);
      c.submitScore(100);
      final second = client.connect(
        '127.0.0.1',
        host.pairingKey!,
        port: host.localPort!,
        actions: true,
      );
      await eventually(() => client.scorer.ready);
      expect(client.scorer.controller!.scores, [441, 401]);
      expect(captures, 0);
      await client.disconnect();
      await second;
      client.dispose();
      host.dispose();
      c.dispose();
    },
  );
}
