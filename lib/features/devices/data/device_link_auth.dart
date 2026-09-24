import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';

class DeviceLinkAuth {
  static String newKey() {
    final random = Random.secure();
    return List.generate(
      32,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }

  static bool validKey(String key) => RegExp(r'^[0-9a-f]{64}$').hasMatch(key);
  static String sign(String key, String message) =>
      Hmac(sha256, utf8.encode(key)).convert(utf8.encode(message)).toString();
  static bool verify(String key, String message, String? signature) {
    final expected = sign(key, message);
    if (signature == null || signature.length != expected.length) return false;
    var difference = 0;
    for (var i = 0; i < expected.length; i++) {
      difference |= expected.codeUnitAt(i) ^ signature.codeUnitAt(i);
    }
    return difference == 0;
  }
}
