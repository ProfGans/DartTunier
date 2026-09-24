import 'dart:convert';
import 'dart:io';
import '../domain/board_display.dart';
import 'board_display_server.dart';
import 'device_link_auth.dart';
import 'pairing_exchange.dart';

class BoardDisplayClient {
  Future<String> requestPairing({
    required String address,
    required String targetId,
    required String name,
    required void Function(String) onConfirmation,
    int port = BoardDisplayServer.defaultPort,
  }) async {
    if (InternetAddress.tryParse(address) == null) {
      throw const FormatException('Ungültige Adresse');
    }
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 3);
    client.findProxy = (_) => 'DIRECT';
    final exchange = await PairingExchange.create();
    try {
      final request = await client.postUrl(
        Uri(scheme: 'http', host: address, port: port, path: '/pair'),
      );
      request.followRedirects = false;
      request.headers.contentType = ContentType.json;
      request.write(
        jsonEncode({
          'name': name,
          'targetId': targetId,
          'publicKey': exchange.publicKey,
        }),
      );
      final response = await request.close().timeout(
        const Duration(seconds: 5),
      );
      if (response.statusCode != 200) {
        throw const HttpException(
          'Kopplung abgelehnt, abgelaufen oder Gerät bereits belegt.',
        );
      }
      final data = jsonDecode(await _read(response)) as Map<String, dynamic>;
      if (data['deviceId'] != targetId ||
          data['publicKey'] is! String ||
          data['token'] is! String) {
        throw const HttpException('Ungültige Kopplungsantwort');
      }
      final key = await exchange.derive(data['publicKey'] as String, targetId);
      onConfirmation(PairingExchange.confirmation(key));
      final deadline = DateTime.now().add(const Duration(seconds: 60));
      while (DateTime.now().isBefore(deadline)) {
        final poll = await client.getUrl(
          Uri(scheme: 'http', host: address, port: port, path: '/pair/status'),
        );
        poll.followRedirects = false;
        poll.headers.set('x-pair-token', data['token'] as String);
        final result = await poll.close().timeout(const Duration(seconds: 3));
        if (result.statusCode != 200) break;
        final status = jsonDecode(await _read(result)) as Map<String, dynamic>;
        if (status['accepted'] == true) return key;
        if (status['accepted'] == false) break;
        await Future<void>.delayed(const Duration(seconds: 1));
      }
      throw const HttpException('Kopplung abgelehnt oder abgelaufen.');
    } finally {
      exchange.dispose();
      client.close(force: true);
    }
  }

  Future<void> send({
    required String address,
    required String targetId,
    required String key,
    required String sourceId,
    required BoardDisplay display,
    int port = BoardDisplayServer.defaultPort,
  }) async {
    if (!DeviceLinkAuth.validKey(key) ||
        InternetAddress.tryParse(address) == null) {
      throw const FormatException('Ungültige Kopplungsdaten');
    }
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 3);
    client.findProxy = (_) => 'DIRECT';
    try {
      final get = await client.getUrl(
        Uri(scheme: 'http', host: address, port: port, path: '/challenge'),
      );
      get.followRedirects = false;
      final response = await get.close().timeout(const Duration(seconds: 3));
      if (response.statusCode != 200) {
        throw const HttpException('Gerät nicht verfügbar');
      }
      final challenge =
          jsonDecode(await _read(response)) as Map<String, dynamic>;
      final nonce = challenge['nonce'];
      if (nonce is! String ||
          !DeviceLinkAuth.validKey(nonce) ||
          challenge['deviceId'] != targetId ||
          !DeviceLinkAuth.verify(
            key,
            'challenge\n$targetId\n$nonce',
            challenge['proof'] as String?,
          )) {
        throw const HttpException(
          'Kopplungscode oder Gerät stimmt nicht überein',
        );
      }
      final body = jsonEncode({
        'sourceId': sourceId,
        'display': display.toJson(),
      });
      final post = await client.postUrl(
        Uri(scheme: 'http', host: address, port: port, path: '/display'),
      );
      post.followRedirects = false;
      post.headers.contentType = ContentType.json;
      post.headers.set('x-device-nonce', nonce);
      post.headers.set(
        'x-device-proof',
        DeviceLinkAuth.sign(key, 'display\n$nonce\n$body'),
      );
      post.write(body);
      final result = await post.close().timeout(const Duration(seconds: 3));
      if (result.statusCode != 200) {
        throw const HttpException('Gerät belegt oder Verbindung abgewiesen');
      }
      final ack = jsonDecode(await _read(result)) as Map<String, dynamic>;
      if (!DeviceLinkAuth.verify(
        key,
        'accepted\n$nonce',
        ack['proof'] as String?,
      )) {
        throw const HttpException('Antwort des Geräts ungültig');
      }
    } finally {
      client.close(force: true);
    }
  }

  Future<String> _read(HttpClientResponse response) async {
    final bytes = <int>[];
    await for (final chunk in response.timeout(const Duration(seconds: 3))) {
      bytes.addAll(chunk);
      if (bytes.length > 8192) throw const HttpException('Antwort zu groß');
    }
    return utf8.decode(bytes);
  }
}
