import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../tournaments/domain/tournament_models.dart';
import '../domain/app_device.dart';
import '../domain/board_display.dart';
import '../data/board_display_client.dart';
import '../data/device_link_auth.dart';
import 'devices_controller.dart';
import 'board_display_projector.dart';

class BoardDeviceConnection {
  BoardDeviceConnection({
    required this.device,
    required this.address,
    required this.key,
  });
  final AppDevice device;
  final String address;
  final String key;
  String status = 'Verbinde …';
}

class BoardDeviceDispatcher extends ChangeNotifier {
  BoardDeviceDispatcher({
    required this.devices,
    required this.tournament,
    required this.activeStage,
    BoardDisplayClient? client,
  }) : _client = client ?? BoardDisplayClient();
  final DevicesController devices;
  final CreatedTournament tournament;
  final int Function() activeStage;
  final BoardDisplayClient _client;
  final connections = <int, BoardDeviceConnection>{};
  Timer? _timer;
  bool _disposed = false;
  bool _sending = false;
  bool _started = false;
  Future<void> _operations = Future<void>.value();
  Future<void> _exclusive(Future<void> Function() action) {
    final result = _operations.then((_) => action());
    _operations = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace stack) {},
    );
    return result;
  }

  Future<void> start() async {
    if (_started) return;
    _started = true;
    await devices.openPage();
    if (_disposed) return;
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => publish());
  }

  Future<void> bind(
    int board,
    DevicePresence peer,
    String key,
  ) => _exclusive(() async {
    if (_disposed) return;
    if (board < 1 ||
        board > tournament.boardCount ||
        !DeviceLinkAuth.validKey(key)) {
      throw const FormatException('Board oder Kopplungscode ungültig');
    }
    if (peer.device.id == devices.settings?.self.id ||
        connections.values.any((c) => c.device.id == peer.device.id)) {
      throw StateError(
        'Dieses Gerät ist bereits zugeordnet. Bitte die bisherige Zuordnung zuerst lösen.',
      );
    }
    if (connections.containsKey(board)) {
      throw StateError('Board ist bereits belegt.');
    }
    connections[board] = BoardDeviceConnection(
      device: peer.device,
      address: peer.address,
      key: key,
    );
    _changed();
    await _publish();
  });

  Future<void> unbind(int board) => _exclusive(() => _unbind(board));
  Future<void> _unbind(int board) async {
    final connection = connections.remove(board);
    _changed();
    if (connection != null) await _release(board, connection);
  }

  Future<void> _release(int board, BoardDeviceConnection connection) async {
    try {
      await _send(
        connection,
        BoardDisplay(
          tournamentId: tournament.id,
          tournamentName: tournament.name,
          board: board,
          state: 'released',
        ),
      );
    } catch (_) {}
  }

  Future<void> _send(
    BoardDeviceConnection connection,
    BoardDisplay display,
  ) async {
    final online = devices.discovery.peers.where(
      (p) => p.device.id == connection.device.id,
    );
    await _client.send(
      address: online.isEmpty ? connection.address : online.first.address,
      targetId: connection.device.id,
      key: connection.key,
      sourceId: devices.settings!.self.id,
      display: display,
    );
  }

  Future<void> publish() {
    if (_disposed || _sending) return Future<void>.value();
    return _exclusive(_publish);
  }

  Future<void> _publish() async {
    if (_disposed || _sending || connections.isEmpty) return;
    _sending = true;
    try {
      final displays = const BoardDisplayProjector().project(
        tournament,
        activeStage(),
      );
      await Future.wait([
        for (final entry in connections.entries.toList())
          () async {
            final display = displays[entry.key];
            if (display == null) {
              await _unbind(entry.key);
              return;
            }
            try {
              await _send(entry.value, display);
              entry.value.status = 'Verbunden';
            } catch (_) {
              entry.value.status =
                  'Nicht verbunden · Kopplungscode, Gerätemodus und Netzwerk prüfen';
            }
          }(),
      ]);
    } finally {
      _sending = false;
      _changed();
    }
  }

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    unawaited(
      _exclusive(() async {
        for (final entry in connections.entries.toList()) {
          await _release(entry.key, entry.value);
        }
        connections.clear();
      }),
    );
    if (_started) devices.closePage();
    super.dispose();
  }
}
