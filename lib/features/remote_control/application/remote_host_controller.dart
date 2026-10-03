import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../../devices/data/device_link_auth.dart';
import '../data/remote_channel.dart';
import '../data/remote_account_repository.dart';
import '../data/remote_settings_storage.dart';
import '../domain/remote_control_settings.dart';
import '../domain/account_remote_device.dart';
import '../../devices/domain/app_device.dart';

class RemoteHostController extends ChangeNotifier {
  RemoteHostController({
    RemoteSettingsStorage? settingsStorage,
    RemoteAccountRepository? accountRepository,
  }) : _settingsStorage = settingsStorage ?? RemoteSettingsStorage(),
       accountRepository = accountRepository ?? RemoteAccountRepository();
  final RemoteSettingsStorage _settingsStorage;
  final RemoteAccountRepository accountRepository;
  RemoteControlSettings _settings = const RemoteControlSettings();
  AppDevice? _device;
  StreamSubscription<String?>? _accountSubscription;
  String? _accountKey, _accountOwner;
  bool _accountConnection = false;
  int _accountGeneration = 0, _listGeneration = 0;
  Future<void> _accountOperations = Future.value();
  List<AccountRemoteDevice> accountDevices = [];
  String? accountError;
  bool settingsReady = false, settingsBusy = false, accountBusy = false;
  bool get requireConfirmation => _settings.requireConfirmation;
  bool get rememberEnabled => _settings.enabled;
  String? get accountId => accountRepository.userId;
  String? pendingName;
  Completer<bool>? _confirmation;

  Future<void> initialize({AppDevice? device}) async {
    if (settingsReady || _disposed) return;
    _device = device;
    try {
      _settings = await _settingsStorage.load();
      if (_disposed) return;
      settingsReady = true;
      _accountSubscription = accountRepository.accountChanges?.listen((owner) {
        if (_accountOwner != owner) {
          _accountGeneration++;
          _accountKey = null;
          _accountOwner = null;
          accountDevices = [];
          if (_accountConnection) {
            answerConfirmation(false);
            unawaited(_socket?.close() ?? Future.value());
          }
          if (enabled) unawaited(_publishAccountAccess());
        }
        unawaited(refreshAccountDevices());
        _changed();
      });
      if (_settings.enabled) await start();
      await refreshAccountDevices();
    } catch (_) {
      error = 'Fernsteuerungseinstellungen konnten nicht geladen werden.';
    }
    _changed();
  }

  Future<void> setEnabled(bool enabled) async {
    if (settingsBusy || _disposed) return;
    if (!await _saveSettings(_settings.copyWith(enabled: enabled))) return;
    if (enabled) {
      await start();
    } else {
      await stop();
    }
  }

  Future<void> setRequireConfirmation(bool required) async {
    if (settingsBusy || _disposed) return;
    if (await _saveSettings(
          _settings.copyWith(requireConfirmation: required),
        ) &&
        !required) {
      answerConfirmation(true);
    }
  }

  Future<bool> _saveSettings(RemoteControlSettings next) async {
    settingsBusy = true;
    error = null;
    _changed();
    try {
      await _settingsStorage.save(next);
      if (_disposed) return false;
      _settings = next;
      return true;
    } catch (_) {
      error = 'Fernsteuerungseinstellungen konnten nicht gespeichert werden.';
      return false;
    } finally {
      settingsBusy = false;
      _changed();
    }
  }

  Future<void> refreshAccountDevices() async {
    if (_disposed) return;
    final generation = ++_listGeneration;
    accountBusy = true;
    accountError = null;
    _changed();
    try {
      if (enabled && _accountKey == null && !starting && accountId != null) {
        await _publishAccountAccess();
      }
      final devices = await accountRepository.load();
      if (!_disposed && generation == _listGeneration) {
        accountDevices = devices
            .where((entry) => entry.device.id != _device?.id)
            .toList();
      }
    } catch (_) {
      if (generation == _listGeneration) {
        accountError =
            'Account-Fernsteuerung nicht erreichbar. Anmeldung und Servereinrichtung prüfen.';
        accountDevices = [];
      }
    } finally {
      if (generation == _listGeneration) {
        accountBusy = false;
        _changed();
      }
    }
  }

  Future<void> _publishAccountAccess() {
    final device = _device, owner = accountId;
    if (device == null || owner == null || !enabled || addresses.isEmpty) {
      return Future.value();
    }
    final generation = ++_accountGeneration;
    _accountKey = null;
    _accountOwner = owner;
    final key = DeviceLinkAuth.newKey();
    final operation = _accountOperations.then((_) async {
      if (_disposed ||
          !enabled ||
          generation != _accountGeneration ||
          owner != accountId) {
        return;
      }
      try {
        await accountRepository.publish(device, addresses, key);
        if (!_disposed &&
            enabled &&
            generation == _accountGeneration &&
            owner == accountId) {
          _accountKey = key;
          accountError = null;
          _changed();
        }
      } catch (_) {
        if (generation == _accountGeneration) {
          accountError =
              'Account-Freigabe konnte nicht eingerichtet werden. Anmeldung und Servereinrichtung prüfen.';
          _changed();
        }
      }
    });
    _accountOperations = operation;
    return operation;
  }

  void answerConfirmation(bool accept) {
    final pending = _confirmation;
    if (pending != null && !pending.isCompleted) pending.complete(accept);
  }

  static const port = 45875;
  HttpServer? _server;
  WebSocket? _socket;
  RemoteChannel? _channel;
  Timer? _timer;
  bool _capturing = false, _awaitingFrame = false, _disposed = false;
  bool starting = false;
  int _generation = 0;
  DateTime? _lastFrame;
  String? pairingKey, error;
  List<String> addresses = [];
  Future<Map<String, dynamic>?> Function()? capture;
  void Function(Map<String, dynamic>)? onInput;
  bool get enabled => _server != null;
  bool get connected => _channel != null;

  Future<void> start({
    InternetAddress? bindAddress,
    int listenPort = port,
  }) async {
    if (enabled || starting || _disposed) return;
    final generation = ++_generation;
    starting = true;
    _changed();
    error = null;
    pairingKey = DeviceLinkAuth.newKey();
    try {
      final server = await HttpServer.bind(
        bindAddress ?? InternetAddress.anyIPv4,
        listenPort,
      );
      if (_disposed || generation != _generation) {
        await server.close(force: true);
        return;
      }
      _server = server;
      addresses = [
        for (final interface in await NetworkInterface.list(
          type: InternetAddressType.IPv4,
        ))
          for (final address in interface.addresses) address.address,
      ];
      if (_disposed || generation != _generation) return;
      server.listen(_request);
      _timer = Timer.periodic(
        const Duration(milliseconds: 250),
        (_) => _frame(),
      );
      await _publishAccountAccess();
    } catch (_) {
      error =
          'Fernsteuerung konnte nicht gestartet werden. Port 45875 und Firewall prüfen.';
      await stop();
    }
    starting = false;
    _changed();
  }

  int? get localPort => _server?.port;
  Future<void> _request(HttpRequest request) async {
    if (request.uri.path != '/remote' ||
        !WebSocketTransformer.isUpgradeRequest(request)) {
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
      return;
    }
    if (_socket != null || _disposed) {
      request.response.statusCode = HttpStatus.conflict;
      await request.response.close();
      return;
    }
    WebSocket? socket;
    try {
      socket = await WebSocketTransformer.upgrade(request);
      if (_socket != null || !enabled) {
        await socket.close();
        return;
      }
      _socket = socket;
      socket.pingInterval = const Duration(seconds: 5);
      final challenge = DeviceLinkAuth.newKey();
      socket.add(jsonEncode({'version': 1, 'challenge': challenge}));
      final stream = StreamIterator<dynamic>(socket);
      if (!await stream.moveNext().timeout(const Duration(seconds: 8))) return;
      if (stream.current is! String ||
          (stream.current as String).length > 2048) {
        return;
      }
      final auth = jsonDecode(stream.current as String) as Map<String, dynamic>;
      final byAccount = auth['mode'] == 'account';
      final key = byAccount ? _accountKey : pairingKey;
      final owner = _accountOwner;
      if (key == null ||
          (byAccount && (owner == null || owner != accountId)) ||
          !DeviceLinkAuth.verify(
            key,
            'remote-v1:$challenge:auth',
            auth['signature'] as String?,
          )) {
        return;
      }
      final channel = RemoteChannel(key, challenge, host: true);
      Future<bool>? confirmationRead;
      _accountConnection = byAccount;
      if (requireConfirmation) {
        final request = Completer<bool>();
        _confirmation = request;
        final name = auth['name'];
        pendingName =
            name is String && name.trim().isNotEmpty && name.length <= 80
            ? name.trim()
            : 'Fernbedienung';
        socket.add(await channel.encode({'type': 'confirmation'}));
        _changed();
        confirmationRead = stream.moveNext();
        final accepted = await Future.any<bool>([
          request.future,
          confirmationRead.then((_) => false),
        ]).timeout(const Duration(seconds: 90), onTimeout: () => false);
        if (identical(_confirmation, request)) {
          _confirmation = null;
          pendingName = null;
          _changed();
        }
        if (!accepted) {
          socket.add(await channel.encode({'type': 'rejected'}));
          return;
        }
      }
      if (byAccount && (owner != accountId || key != _accountKey)) return;
      socket.add(await channel.encode({'type': 'ready'}));
      if (!identical(socket, _socket) || !enabled) return;
      _channel = channel;
      _changed();
      var next = confirmationRead ?? stream.moveNext();
      while (await next) {
        if (!identical(socket, _socket) || !enabled) break;
        if (stream.current is! String ||
            (stream.current as String).length > 100000) {
          break;
        }
        final message = await channel.decode(stream.current);
        if (!identical(socket, _socket) || !enabled) break;
        if (message['type'] == 'frameAck') {
          _awaitingFrame = false;
        } else {
          onInput?.call(message);
        }
        next = stream.moveNext();
      }
    } catch (_) {
      // A failed pairing or lost connection never mutates the host session.
    } finally {
      if (identical(_socket, socket)) {
        answerConfirmation(false);
        _confirmation = null;
        pendingName = null;
        _accountConnection = false;
        onInput?.call({'type': 'cancel'});
        _socket = null;
        _channel = null;
        _awaitingFrame = false;
        _changed();
      }
      await socket?.close();
    }
  }

  Future<void> _frame() async {
    final socket = _socket;
    final channel = _channel;
    if (_capturing || socket == null || channel == null) return;
    if (_awaitingFrame) {
      if (_lastFrame != null &&
          DateTime.now().difference(_lastFrame!) >
              const Duration(seconds: 15)) {
        unawaited(socket.close());
      }
      return;
    }
    _capturing = true;
    try {
      final frame = await capture?.call();
      if (frame != null && identical(socket, _socket)) {
        _awaitingFrame = true;
        _lastFrame = DateTime.now();
        socket.add(await channel.encode(frame));
      }
    } catch (_) {
      // A view being resized or removed is captured again on the next tick.
    } finally {
      _capturing = false;
    }
  }

  Future<void> stop() async {
    final owner = _accountOwner, deviceId = _device?.id;
    _accountGeneration++;
    _accountKey = null;
    _accountOwner = null;
    _accountConnection = false;
    answerConfirmation(false);
    _confirmation = null;
    pendingName = null;
    _generation++;
    starting = false;
    _timer?.cancel();
    final server = _server;
    _server = null;
    final socket = _socket;
    _socket = null;
    _channel = null;
    _awaitingFrame = false;
    pairingKey = null;
    onInput?.call({'type': 'cancel'});
    _changed();
    await socket?.close();
    await server?.close(force: true);
    if (owner != null && deviceId != null) {
      final revoke = _accountOperations.then((_) async {
        if (owner != accountId) return;
        try {
          await accountRepository.revoke(deviceId);
        } catch (_) {
          /* Local session keys are already revoked. */
        }
      });
      _accountOperations = revoke;
      await revoke;
    }
    _changed();
  }

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_accountSubscription?.cancel() ?? Future.value());
    unawaited(stop());
    super.dispose();
  }
}
