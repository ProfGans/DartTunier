import 'dart:async';
import 'package:flutter/foundation.dart';
import '../data/device_account_repository.dart';
import '../data/device_settings_storage.dart';
import '../data/lan_device_discovery.dart';
import '../domain/app_device.dart';
import '../data/board_display_server.dart';
import '../data/device_link_auth.dart';

class DevicesController extends ChangeNotifier {
  DevicesController({
    DeviceSettingsStorage? storage,
    LanDeviceDiscovery? discovery,
    DeviceAccountRepository? accountRepository,
    BoardDisplayServer? receiver,
  }) : _storage = storage ?? DeviceSettingsStorage(),
       discovery = discovery ?? LanDeviceDiscovery(),
       accountRepository = accountRepository ?? DeviceAccountRepository(),
       receiver = receiver ?? BoardDisplayServer() {
    this.discovery.addListener(_changed);
    this.receiver.addListener(_changed);
    _authSubscription = this.accountRepository.authChanges?.listen((_) {
      final current = this.accountRepository.userId;
      if (current != _accountId) {
        _accountRequest++;
        _accountId = current;
        accountDevices = [];
        accountError = null;
        _changed();
      }
    });
  }
  final DeviceSettingsStorage _storage;
  final LanDeviceDiscovery discovery;
  final DeviceAccountRepository accountRepository;
  final BoardDisplayServer receiver;
  bool showDisplay = true;
  void setShowDisplay(bool show) {
    showDisplay = show;
    _changed();
  }

  Future<void> resetPairing() => _run(() async {
    await _save(settings!.copyWith(pairingKey: DeviceLinkAuth.newKey()));
  });
  StreamSubscription<dynamic>? _authSubscription;
  DeviceSettings? settings;
  List<AppDevice> accountDevices = [];
  String? error;
  String? accountError;
  String? _accountId;
  bool busy = false;
  bool _disposed = false;
  int _openPages = 0;
  int _accountRequest = 0;
  Future<void>? _initialization;

  Future<void> initialize() => _initialization ??= _initialize();
  Future<void> _initialize() async {
    error = null;
    try {
      final loaded = await _storage.load();
      if (_disposed) return;
      settings = loaded;
      await _configure();
    } catch (_) {
      error = 'Geräteeinstellungen konnten nicht geladen werden.';
    }
    _changed();
  }

  Future<void> openPage({bool loadAccount = true}) async {
    _openPages++;
    await initialize();
    if (_disposed) return;
    await _configure();
    if (loadAccount) await refreshAccount();
  }

  void closePage() {
    if (_openPages > 0) _openPages--;
    unawaited(Future<void>.microtask(_configure));
  }

  Future<void> _configure() async {
    if (settings != null && !_disposed) {
      await discovery.configure(settings!, scanning: _openPages > 0);
      if (_disposed) return;
      final key = settings!.pairingKey;
      if (key != null) {
        await receiver.configure(
          deviceId: settings!.self.id,
          key: key,
          enabled: settings!.enabled,
        );
      }
    }
  }

  Future<void> refresh() async {
    if (settings == null) {
      _initialization = null;
      await initialize();
    }
    await _configure();
    await refreshAccount();
  }

  Future<void> refreshAccount() async {
    final request = ++_accountRequest;
    final owner = accountRepository.userId;
    if (_accountId != owner) accountDevices = [];
    _accountId = owner;
    accountError = null;
    _changed();
    if (owner == null) return;
    try {
      final devices = await accountRepository.load();
      if (!_disposed &&
          request == _accountRequest &&
          owner == accountRepository.userId) {
        accountDevices = devices;
      }
    } catch (_) {
      if (request == _accountRequest && owner == accountRepository.userId) {
        accountError =
            'Account-Geräte konnten nicht geladen werden. Verbindung prüfen; die Gerätefunktion muss auf dem Server eingerichtet sein.';
      }
    }
    _changed();
  }

  Future<void> _run(Future<void> Function() action) async {
    if (busy || _disposed) return;
    busy = true;
    error = null;
    _changed();
    try {
      await action();
    } catch (_) {
      error =
          'Änderung konnte nicht gespeichert werden. Bitte erneut versuchen.';
    } finally {
      busy = false;
      _changed();
    }
  }

  Future<void> _save(DeviceSettings next) async {
    await _storage.save(next);
    if (_disposed) return;
    settings = next;
    await _configure();
  }

  Future<void> setEnabled(bool enabled) =>
      _run(() => _save(settings!.copyWith(enabled: enabled)));
  Future<void> rename(String name) => _run(() async {
    final trimmed = name.trim();
    if (trimmed.isEmpty || trimmed.length > 80) {
      throw ArgumentError('Ungültiger Name');
    }
    await _save(
      settings!.copyWith(
        self: AppDevice(
          id: settings!.self.id,
          name: trimmed,
          platform: settings!.self.platform,
        ),
      ),
    );
  });
  Future<void> remember(AppDevice device) => _run(() async {
    if (device.id == settings!.self.id) return;
    await _save(
      settings!.copyWith(
        savedDevices: [
          ...settings!.savedDevices.where((d) => d.id != device.id),
          device,
        ],
      ),
    );
  });
  Future<void> forget(String id) => _run(
    () => _save(
      settings!.copyWith(
        savedDevices: settings!.savedDevices.where((d) => d.id != id).toList(),
      ),
    ),
  );
  Future<void> registerSelf() => _run(() async {
    await accountRepository.register(settings!.self);
    await refreshAccount();
  });
  Future<void> removeAccountDevice(String id) => _run(() async {
    await accountRepository.remove(id);
    await refreshAccount();
  });
  void _changed() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _authSubscription?.cancel();
    discovery.removeListener(_changed);
    discovery.dispose();
    receiver.removeListener(_changed);
    receiver.dispose();
    super.dispose();
  }
}
