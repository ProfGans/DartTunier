import '../../devices/domain/app_device.dart';

class AccountRemoteDevice {
  const AccountRemoteDevice({
    required this.device,
    required this.addresses,
    required this.key,
  });
  final AppDevice device;
  final List<String> addresses;
  final String key;
  factory AccountRemoteDevice.fromJson(Map<String, dynamic> json) {
    final key = json['session_key'];
    final addresses = json['addresses'];
    if (key is! String ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(key) ||
        addresses is! List ||
        addresses.isEmpty ||
        addresses.length > 32 ||
        addresses.any(
          (address) =>
              address is! String ||
              !RegExp(r'^[0-9.]{7,15}$').hasMatch(address),
        )) {
      throw const FormatException('Ungültige Account-Fernsteuerung');
    }
    return AccountRemoteDevice(
      device: AppDevice.fromJson({
        'id': json['device_id'],
        'name': json['name'],
        'platform': json['platform'],
      }),
      addresses: List<String>.from(addresses),
      key: key,
    );
  }
}
