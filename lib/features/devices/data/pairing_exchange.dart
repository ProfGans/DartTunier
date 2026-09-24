import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:cryptography/cryptography.dart' hide Hmac;

/// Ephemeral X25519 exchange. Only public keys travel over the LAN.
class PairingExchange {
  PairingExchange._(this._pair, this.publicKey);
  final SimpleKeyPair _pair;
  final String publicKey;
  static Future<PairingExchange> create() async {
    final pair = await X25519().newKeyPair();
    return PairingExchange._(
      pair,
      base64Encode((await pair.extractPublicKey()).bytes),
    );
  }

  Future<String> derive(String remote, String targetId) async {
    final bytes = base64Decode(remote);
    if (bytes.length != 32) {
      throw const FormatException('Ungültiger öffentlicher Schlüssel');
    }
    final secret = await X25519().sharedSecretKey(
      keyPair: _pair,
      remotePublicKey: SimplePublicKey(bytes, type: KeyPairType.x25519),
    );
    final shared = await secret.extractBytes();
    if (shared.every((b) => b == 0)) {
      throw const FormatException('Ungültiger Schlüsselaustausch');
    }
    return Hmac(
      sha256,
      shared,
    ).convert(utf8.encode('dart-device-pair-v1\n$targetId')).toString();
  }

  static String confirmation(String key) =>
      (int.parse(
                sha256
                    .convert(utf8.encode('confirm\n$key'))
                    .toString()
                    .substring(0, 8),
                radix: 16,
              ) %
              1000000)
          .toString()
          .padLeft(6, '0');
  void dispose() => _pair.destroy();
}
