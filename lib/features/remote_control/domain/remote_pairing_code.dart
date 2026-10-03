import '../../devices/data/device_link_auth.dart';

class RemotePairingCode {
  const RemotePairingCode(this.address, this.key);
  final String address, key;
  String encode() => Uri(
    scheme: 'dartturnier',
    host: 'remote',
    path: '/connect',
    queryParameters: {'version': '1', 'address': address, 'key': key},
  ).toString();
  static RemotePairingCode? parse(String value) {
    if (value.length > 512) return null;
    final uri = Uri.tryParse(value);
    if (uri == null ||
        uri.scheme != 'dartturnier' ||
        uri.host != 'remote' ||
        uri.path != '/connect' ||
        uri.queryParameters['version'] != '1') {
      return null;
    }
    final address = uri.queryParameters['address'],
        key = uri.queryParameters['key'];
    if (address == null ||
        address.isEmpty ||
        address.length > 253 ||
        !RegExp(r'^[a-zA-Z0-9.:-]+$').hasMatch(address) ||
        key == null ||
        !DeviceLinkAuth.validKey(key)) {
      return null;
    }
    return RemotePairingCode(address, key);
  }
}
