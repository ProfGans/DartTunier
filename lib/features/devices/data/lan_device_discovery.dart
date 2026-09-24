import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../domain/app_device.dart';

class LanDeviceDiscovery extends ChangeNotifier {
  LanDeviceDiscovery({
    this.listenPort = port,
    InternetAddress? bindAddress,
    this.broadcast = true,
    this.recoveryInterval = const Duration(seconds: 15),
  }) : _bindAddress = bindAddress ?? InternetAddress.anyIPv4;
  static const port = 45873;
  final int listenPort;
  final InternetAddress _bindAddress;
  final bool broadcast;
  final Duration recoveryInterval;
  int? get localPort => _socket?.port;
  static final group = InternetAddress('239.255.77.77');
  RawDatagramSocket? _socket;
  StreamSubscription<RawSocketEvent>? _subscription;
  Timer? _timer;
  Timer? _recovery;
  DeviceSettings? _settings;
  bool _scanning = false;
  bool _disposed = false;
  int _generation = 0;
  List<NetworkInterface> _interfaces = [];
  final Map<String, DevicePresence> _peers = {};
  final Map<String, DateTime> _responses = {};
  String? error;
  List<DevicePresence> get peers =>
      _peers.values.toList()
        ..sort((a, b) => a.device.name.compareTo(b.device.name));

  Future<void> configure(
    DeviceSettings settings, {
    required bool scanning,
  }) async {
    if (_disposed) return;
    if (Platform.isAndroid) {
      try {
        await const MethodChannel(
          'dartturnier/discovery',
        ).invokeMethod<void>('setActive', settings.enabled || scanning);
      } on PlatformException catch (_) {
        // UDP retry remains available if the platform cannot acquire the lock.
      } on MissingPluginException catch (_) {}
      if (_disposed) return;
    }
    _recovery ??= Timer.periodic(recoveryInterval, (_) {
      final current = _settings;
      if (current != null && (current.enabled || _scanning)) {
        unawaited(configure(current, scanning: _scanning));
      }
    });
    final generation = ++_generation;
    if (_settings?.enabled == true && !settings.enabled) _announce('goodbye');
    _settings = settings;
    _scanning = scanning;
    _stop();
    _responses.clear();
    _peers.removeWhere((_, peer) => !peer.isFresh(DateTime.now()));
    error = null;
    if (!settings.enabled && !scanning) {
      _peers.clear();
      _changed();
      return;
    }
    RawDatagramSocket? pending;
    try {
      pending = await RawDatagramSocket.bind(
        _bindAddress,
        listenPort,
        reuseAddress: true,
      );
      if (_disposed || generation != _generation) {
        pending.close();
        return;
      }
      _socket = pending;
      pending.broadcastEnabled = true;
      pending.writeEventsEnabled = false;
      pending.multicastHops = 1;
      _interfaces = broadcast
          ? await NetworkInterface.list(type: InternetAddressType.IPv4)
          : [];
      if (_disposed || generation != _generation) return;
      for (final interface in _interfaces) {
        try {
          pending.joinMulticast(group, interface);
        } on SocketException {
          /* Broadcast remains available. */
        }
      }
      _subscription = pending.listen(
        (event) {
          if (event != RawSocketEvent.read) return;
          Datagram? datagram;
          while ((datagram = _socket?.receive()) != null) {
            _receive(datagram!);
          }
        },
        onError: (Object _) {
          _stop();
          error =
              'Netzwerkerkennung unterbrochen. Suche wird automatisch wiederholt.';
          _changed();
        },
      );
      _tick();
      _timer = Timer.periodic(const Duration(seconds: 5), (_) => _tick());
    } catch (_) {
      pending?.close();
      if (!_disposed && generation == _generation) {
        _stop();
        error =
            'Netzwerkerkennung nicht verfügbar. Netzwerk und Firewall prüfen.';
        _changed();
      }
    }
  }

  void _receive(Datagram datagram) {
    final message = DeviceDiscoveryMessage.decode(datagram.data);
    if (message == null || message.device.id == _settings?.self.id) return;
    final now = DateTime.now();
    if (message.kind == 'query') {
      if (_settings?.enabled != true) return;
      final last = _responses[datagram.address.address];
      if (last != null && now.difference(last) < const Duration(seconds: 1)) {
        return;
      }
      if (_responses.length >= 128) _responses.clear();
      _responses[datagram.address.address] = now;
      _send(
        DeviceDiscoveryMessage('presence', _settings!.self).encode(),
        datagram.address,
        datagram.port,
      );
      return;
    }
    if (message.kind == 'goodbye') {
      _peers.remove(message.device.id);
    } else if (_peers.containsKey(message.device.id) || _peers.length < 128) {
      _peers[message.device.id] = DevicePresence(
        device: message.device,
        address: datagram.address.address,
        seenAt: now,
      );
    }
    _changed();
  }

  void _tick() {
    _peers.removeWhere((_, peer) => !peer.isFresh(DateTime.now()));
    if (_settings?.enabled == true) _announce('presence');
    if (_scanning) _announce('query');
    // Unicast keeps known peers reachable when Wi-Fi filters broadcast packets.
    if (_settings != null) {
      for (final peer in _peers.values) {
        _send(
          DeviceDiscoveryMessage('query', _settings!.self).encode(),
          InternetAddress(peer.address),
          port,
        );
      }
    }
    _changed();
  }

  void _announce(String kind) {
    if (!broadcast) return;
    if (_settings == null || _socket == null) return;
    final bytes = DeviceDiscoveryMessage(kind, _settings!.self).encode();
    _send(bytes, InternetAddress('255.255.255.255'), port);
    _send(bytes, group, port);
  }

  void _send(List<int> data, InternetAddress address, int targetPort) {
    try {
      _socket?.send(data, address, targetPort);
    } on SocketException {
      error =
          'Netzwerksuche konnte nicht gesendet werden. Bitte erneut suchen.';
    }
  }

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
    _subscription?.cancel();
    _subscription = null;
    _socket?.close();
    _socket = null;
  }

  @override
  void dispose() {
    if (_settings?.enabled == true) _announce('goodbye');
    _disposed = true;
    _recovery?.cancel();
    if (Platform.isAndroid) {
      unawaited(
        const MethodChannel(
          'dartturnier/discovery',
        ).invokeMethod<void>('setActive', false).catchError((Object _) {}),
      );
    }
    _generation++;
    _stop();
    super.dispose();
  }
}
