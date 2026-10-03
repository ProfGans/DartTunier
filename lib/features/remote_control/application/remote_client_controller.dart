import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../../devices/data/device_link_auth.dart';
import '../data/remote_channel.dart';
import 'remote_host_controller.dart';

class RemoteClientController extends ChangeNotifier {
  WebSocket? _socket;
  RemoteChannel? _channel;
  bool connecting = false, _disposed = false;
  bool awaitingConfirmation = false;
  int _generation = 0;
  String? error;
  Uint8List? image;
  double width = 1, height = 1;
  String? editingText;
  int viewport = 0, editor = 0;
  bool obscureText = false;
  bool get connected => _channel != null;
  Future<void> _sendQueue = Future.value();

  Future<void> connect(
    String address,
    String key, {
    int port = RemoteHostController.port,
    String mode = 'code',
    String name = 'Fernbedienung',
  }) async {
    await disconnect();
    final generation = ++_generation;
    connecting = true;
    error = null;
    _changed();
    WebSocket? socket;
    try {
      if (!DeviceLinkAuth.validKey(key)) {
        throw const FormatException('Code');
      }
      final uri = Uri(
        scheme: 'ws',
        host: address.trim(),
        port: port,
        path: '/remote',
      );
      socket = await WebSocket.connect(
        uri.toString(),
      ).timeout(const Duration(seconds: 8));
      if (_disposed || generation != _generation) {
        await socket.close();
        return;
      }
      _socket = socket;
      socket.pingInterval = const Duration(seconds: 5);
      final stream = StreamIterator<dynamic>(socket);
      if (!await stream.moveNext().timeout(const Duration(seconds: 8))) {
        throw const FormatException('Keine Antwort');
      }
      final hello =
          jsonDecode(stream.current as String) as Map<String, dynamic>;
      final challenge = hello['challenge'] as String;
      if (hello['version'] != 1 || !DeviceLinkAuth.validKey(challenge)) {
        throw const FormatException('Version');
      }
      final channel = RemoteChannel(key, challenge, host: false);
      socket.add(
        jsonEncode({
          'signature': DeviceLinkAuth.sign(key, 'remote-v1:$challenge:auth'),
          'mode': mode,
          'name': name,
        }),
      );
      if (!await stream.moveNext().timeout(const Duration(seconds: 8))) {
        throw const FormatException('Kopplung');
      }
      var response = await channel.decode(stream.current);
      if (response['type'] == 'confirmation') {
        awaitingConfirmation = true;
        _changed();
        if (!await stream.moveNext().timeout(const Duration(seconds: 95))) {
          throw const FormatException('Bestätigung');
        }
        response = await channel.decode(stream.current);
      }
      if (response['type'] == 'rejected') {
        if (generation == _generation) {
          error =
              'Die Übernahme wurde abgelehnt oder nicht rechtzeitig bestätigt.';
        }
        return;
      }
      if (response['type'] != 'ready') throw const FormatException('Kopplung');
      if (generation != _generation) return;
      _channel = channel;
      connecting = false;
      awaitingConfirmation = false;
      _changed();
      while (await stream.moveNext()) {
        if (generation != _generation || _disposed) break;
        final message = await channel.decode(stream.current);
        if (generation != _generation || _disposed) break;
        if (message['type'] != 'frame') {
          throw const FormatException('Nachricht');
        }
        final w = (message['width'] as num).toDouble();
        final h = (message['height'] as num).toDouble();
        if (!w.isFinite ||
            !h.isFinite ||
            w <= 0 ||
            h <= 0 ||
            w > 16000 ||
            h > 16000) {
          throw const FormatException('Bildgröße');
        }
        image = base64Decode(message['image'] as String);
        width = w;
        height = h;
        editingText = message['editingText'] as String?;
        viewport = message['viewport'] as int;
        editor = message['editor'] as int;
        obscureText = message['obscureText'] == true;
        _changed();
        await send({'type': 'frameAck'});
      }
      if (generation == _generation) {
        error = 'Verbindung beendet. Du kannst dich erneut verbinden.';
      }
    } catch (_) {
      if (generation == _generation) {
        error =
            'Verbindung fehlgeschlagen oder unterbrochen. Adresse, Kopplungscode und WLAN prüfen.';
      }
    } finally {
      await socket?.close();
      if (generation == _generation) {
        _socket = null;
        _channel = null;
        connecting = false;
        awaitingConfirmation = false;
        image = null;
        _changed();
      }
    }
  }

  Future<void> send(Map<String, dynamic> message) {
    final socket = _socket, channel = _channel;
    final next = _sendQueue.then((_) async {
      if (socket == null || channel == null || !identical(socket, _socket)) {
        return;
      }
      try {
        socket.add(await channel.encode(message));
      } catch (_) {
        unawaited(socket.close());
      }
    });
    _sendQueue = next;
    return next;
  }

  Future<void> disconnect() async {
    _generation++;
    final socket = _socket;
    _socket = null;
    _channel = null;
    image = null;
    editingText = null;
    connecting = false;
    awaitingConfirmation = false;
    await socket?.close();
    _changed();
  }

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(disconnect());
    super.dispose();
  }
}
