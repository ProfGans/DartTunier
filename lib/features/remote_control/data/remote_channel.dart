import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import '../../devices/data/device_link_auth.dart';

/// Each connection has fresh directional keys and strictly ordered messages.
class RemoteChannel {
  RemoteChannel(String pairingKey, String challenge, {required bool host})
    : _sendKey = _key(pairingKey, challenge, host ? 'host' : 'client'),
      _receiveKey = _key(pairingKey, challenge, host ? 'client' : 'host');
  final SecretKey _sendKey, _receiveKey;
  final _cipher = AesGcm.with256bits();
  int _sent = 0, _received = 0;

  static SecretKey _key(String key, String challenge, String direction) {
    final hex = DeviceLinkAuth.sign(key, 'remote-v1:$challenge:$direction');
    return SecretKey([
      for (var i = 0; i < hex.length; i += 2)
        int.parse(hex.substring(i, i + 2), radix: 16),
    ]);
  }

  Future<String> encode(Map<String, dynamic> message) async {
    final sequence = ++_sent;
    final box = await _cipher.encrypt(
      utf8.encode(jsonEncode({'sequence': sequence, 'message': message})),
      secretKey: _sendKey,
    );
    return jsonEncode({
      'nonce': base64Encode(box.nonce),
      'data': base64Encode(box.cipherText),
      'mac': base64Encode(box.mac.bytes),
    });
  }

  Future<Map<String, dynamic>> decode(dynamic packet) async {
    if (packet is! String || packet.length > 12000000) {
      throw const FormatException('Ungültige Nachricht');
    }
    final envelope = jsonDecode(packet) as Map<String, dynamic>;
    final bytes = await _cipher.decrypt(
      SecretBox(
        base64Decode(envelope['data'] as String),
        nonce: base64Decode(envelope['nonce'] as String),
        mac: Mac(base64Decode(envelope['mac'] as String)),
      ),
      secretKey: _receiveKey,
    );
    final decoded = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    if (decoded['sequence'] != _received + 1) {
      throw const FormatException('Veraltete Nachricht');
    }
    _received++;
    return Map<String, dynamic>.from(decoded['message'] as Map);
  }
}
