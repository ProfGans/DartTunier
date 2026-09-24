import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../domain/board_display.dart';
import 'device_link_auth.dart';
import 'pairing_exchange.dart';

class BoardDisplayServer extends ChangeNotifier {
  static const defaultPort = 45874;
  BoardDisplayServer({this.port = defaultPort, InternetAddress? bindAddress})
    : bindAddress = bindAddress ?? InternetAddress.anyIPv4;
  final int port;
  final InternetAddress bindAddress;
  HttpServer? _server;
  Timer? _expiry;
  String? _deviceId;
  String? _key;
  String? _source;
  DateTime? _seen;
  int _generation = 0;
  bool _disposed = false;
  final _challenges = <String, DateTime>{};
  BoardDisplay? display;
  String? error;
  String? pairingName;
  String? pairingAddress;
  String? pairingCode;
  String? _pairingToken;
  String? _pendingKey;
  String? _sessionKey;
  bool? _pairingAccepted;
  Timer? _pairingExpiry;
  void answerPairing(bool accept) {
    if (_pairingToken == null || pairingName == null) return;
    if (connected) accept = false;
    _pairingAccepted = accept;
    if (accept) {
      _sessionKey = _pendingKey;
      _challenges.clear();
    }
    pairingName = null;
    pairingAddress = null;
    pairingCode = null;
    _changed();
  }

  int? get localPort => _server?.port;
  bool get connected =>
      _seen != null &&
      DateTime.now().difference(_seen!) < const Duration(seconds: 20);

  Future<void> configure({
    required String deviceId,
    required String key,
    required bool enabled,
  }) async {
    if (enabled && _server != null && _deviceId == deviceId && _key == key) {
      return;
    }
    final generation = ++_generation;
    await _stop();
    if (_disposed || generation != _generation) return;
    _deviceId = deviceId;
    _key = key;
    error = null;
    if (!enabled) {
      _changed();
      return;
    }
    try {
      final server = await HttpServer.bind(bindAddress, port);
      if (_disposed || generation != _generation) {
        await server.close(force: true);
        return;
      }
      _server = server;
      server.idleTimeout = const Duration(seconds: 5);
      server.listen(
        (request) => _handle(request, generation),
        onError: (Object _) {
          error = 'Geräteempfang unterbrochen.';
          _changed();
        },
      );
      _expiry = Timer.periodic(const Duration(seconds: 2), (_) {
        if (!connected && _source != null) {
          _source = null;
          _changed();
        }
      });
    } catch (_) {
      error = 'Spielanzeige nicht erreichbar. Port 45874 und Firewall prüfen.';
    }
    _changed();
  }

  Future<void> _handle(HttpRequest request, int generation) async {
    final response = request.response;
    response.headers.contentType = ContentType.json;
    try {
      if (generation != _generation || _key == null) {
        response.statusCode = 503;
        return;
      }
      final now = DateTime.now();
      if (request.method == 'GET' && request.uri.path == '/pair/status') {
        if (_pairingToken == null ||
            request.headers.value('x-pair-token') != _pairingToken) {
          response.statusCode = 403;
          return;
        }
        response.write(jsonEncode({'accepted': _pairingAccepted}));
        if (_pairingAccepted != null) _clearPairing();
        return;
      }
      if (request.method == 'POST' && request.uri.path == '/pair') {
        if (_pairingToken != null || connected) {
          response.statusCode = 409;
          return;
        }
        final bytes = <int>[];
        await for (final chunk in request.timeout(const Duration(seconds: 3))) {
          bytes.addAll(chunk);
          if (bytes.length > 1024) {
            response.statusCode = 413;
            return;
          }
        }
        final data = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
        final name = data['name'];
        if (name is! String ||
            name.trim().isEmpty ||
            name.length > 80 ||
            data['publicKey'] is! String ||
            data['targetId'] != _deviceId) {
          response.statusCode = 400;
          return;
        }
        if (_pairingToken != null || generation != _generation) {
          response.statusCode = 409;
          return;
        }
        final token = DeviceLinkAuth.newKey();
        _pairingToken = token;
        final exchange = await PairingExchange.create();
        try {
          final key = await exchange.derive(
            data['publicKey'] as String,
            _deviceId!,
          );
          if (generation != _generation) {
            response.statusCode = 503;
            return;
          }
          _pendingKey = key;
          _pairingAccepted = null;
          pairingName = name;
          pairingAddress = request.connectionInfo?.remoteAddress.address;
          pairingCode = PairingExchange.confirmation(key);
          _pairingExpiry = Timer(const Duration(seconds: 60), _clearPairing);
          response.write(
            jsonEncode({
              'deviceId': _deviceId,
              'publicKey': exchange.publicKey,
              'token': token,
            }),
          );
          _changed();
        } catch (_) {
          _clearPairing();
          rethrow;
        } finally {
          exchange.dispose();
        }
        return;
      }
      _challenges.removeWhere(
        (_, created) => now.difference(created) > const Duration(seconds: 10),
      );
      if (request.method == 'GET' && request.uri.path == '/challenge') {
        if (_challenges.length >= 64) {
          response.statusCode = 429;
          return;
        }
        final nonce = DeviceLinkAuth.newKey();
        _challenges[nonce] = now;
        response.write(
          jsonEncode({
            'nonce': nonce,
            'deviceId': _deviceId,
            'proof': DeviceLinkAuth.sign(
              _sessionKey ?? _key!,
              'challenge\n$_deviceId\n$nonce',
            ),
          }),
        );
        return;
      }
      if (request.method != 'POST' || request.uri.path != '/display') {
        response.statusCode = 404;
        return;
      }
      final nonce = request.headers.value('x-device-nonce');
      final issued = _challenges.remove(nonce);
      if (issued == null ||
          now.difference(issued) > const Duration(seconds: 10)) {
        response.statusCode = 401;
        return;
      }
      final bytes = <int>[];
      await for (final chunk in request.timeout(const Duration(seconds: 3))) {
        bytes.addAll(chunk);
        if (bytes.length > 8192) {
          response.statusCode = 413;
          return;
        }
      }
      final body = utf8.decode(bytes);
      if (generation != _generation ||
          !DeviceLinkAuth.verify(
            _sessionKey ?? _key!,
            'display\n$nonce\n$body',
            request.headers.value('x-device-proof'),
          )) {
        response.statusCode = 401;
        return;
      }
      final json = jsonDecode(body) as Map<String, dynamic>;
      final source = json['sourceId'];
      if (source is! String || !RegExp(r'^[0-9a-f]{32}$').hasMatch(source)) {
        response.statusCode = 400;
        return;
      }
      if (connected && _source != null && _source != source) {
        response.statusCode = 409;
        return;
      }
      final next = BoardDisplay.fromJson(
        json['display'] as Map<String, dynamic>,
      );
      display = next.state == 'released' ? null : next;
      _source = next.state == 'released' ? null : source;
      _seen = next.state == 'released' ? null : DateTime.now();
      response.write(
        jsonEncode({
          'proof': DeviceLinkAuth.sign(
            _sessionKey ?? _key!,
            'accepted\n$nonce',
          ),
        }),
      );
      _changed();
    } catch (_) {
      response.statusCode = 400;
    } finally {
      try {
        await response.close();
      } catch (_) {}
    }
  }

  Future<void> _stop() async {
    _clearPairing();
    _sessionKey = null;
    _expiry?.cancel();
    _expiry = null;
    final server = _server;
    _server = null;
    _challenges.clear();
    _source = null;
    _seen = null;
    display = null;
    await server?.close(force: true);
  }

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  void _clearPairing() {
    _pairingExpiry?.cancel();
    _pairingToken = null;
    _pendingKey = null;
    _pairingAccepted = null;
    pairingName = null;
    pairingAddress = null;
    pairingCode = null;
    _changed();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    unawaited(_stop());
    super.dispose();
  }
}
