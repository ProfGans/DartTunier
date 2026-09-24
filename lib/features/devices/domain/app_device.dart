import 'dart:convert';

class AppDevice {
  const AppDevice({
    required this.id,
    required this.name,
    required this.platform,
  });
  final String id;
  final String name;
  final String platform;
  static final _idPattern = RegExp(r'^[a-f0-9]{32}$');

  factory AppDevice.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final name = json['name'];
    final platform = json['platform'];
    if (id is! String ||
        !_idPattern.hasMatch(id) ||
        name is! String ||
        name.trim().isEmpty ||
        name.length > 80 ||
        platform is! String ||
        platform.isEmpty ||
        platform.length > 32) {
      throw const FormatException('Ungültige Gerätedaten');
    }
    return AppDevice(id: id, name: name.trim(), platform: platform);
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'platform': platform,
  };
}

class DeviceSettings {
  const DeviceSettings({
    required this.self,
    this.enabled = false,
    this.savedDevices = const [],
    this.pairingKey,
  });
  final AppDevice self;
  final bool enabled;
  final List<AppDevice> savedDevices;
  final String? pairingKey;

  DeviceSettings copyWith({
    AppDevice? self,
    bool? enabled,
    List<AppDevice>? savedDevices,
    String? pairingKey,
  }) => DeviceSettings(
    self: self ?? this.self,
    enabled: enabled ?? this.enabled,
    savedDevices: savedDevices ?? this.savedDevices,
    pairingKey: pairingKey ?? this.pairingKey,
  );

  Map<String, dynamic> toJson() => {
    'schemaVersion': 2,
    'pairingKey': pairingKey,
    'self': self.toJson(),
    'enabled': enabled,
    'savedDevices': savedDevices.map((d) => d.toJson()).toList(),
  };

  factory DeviceSettings.fromJson(Map<String, dynamic> json) {
    if (json['schemaVersion'] != 1 && json['schemaVersion'] != 2) {
      throw const FormatException('Unbekannte Geräteversion');
    }
    return DeviceSettings(
      self: AppDevice.fromJson(json['self'] as Map<String, dynamic>),
      enabled: json['enabled'] as bool? ?? false,
      pairingKey: json['pairingKey'] as String?,
      savedDevices: [
        for (final row in json['savedDevices'] as List? ?? [])
          AppDevice.fromJson(Map<String, dynamic>.from(row as Map)),
      ],
    );
  }
}

class DevicePresence {
  const DevicePresence({
    required this.device,
    required this.address,
    required this.seenAt,
  });
  final AppDevice device;
  final String address;
  final DateTime seenAt;
  bool isFresh(DateTime now) =>
      now.difference(seenAt) < const Duration(seconds: 90);
}

/// Discovery only. No account credentials, game data or execution commands.
class DeviceDiscoveryMessage {
  const DeviceDiscoveryMessage(this.kind, this.device);
  final String kind;
  final AppDevice device;

  List<int> encode() => utf8.encode(
    jsonEncode({
      'app': 'dart-tournament-devices',
      'version': 1,
      'kind': kind,
      'device': device.toJson(),
    }),
  );

  static DeviceDiscoveryMessage? decode(List<int> bytes) {
    if (bytes.length > 1024) return null;
    try {
      final json = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      if (json['app'] != 'dart-tournament-devices' ||
          json['version'] != 1 ||
          !['query', 'presence', 'goodbye'].contains(json['kind'])) {
        return null;
      }
      return DeviceDiscoveryMessage(
        json['kind'] as String,
        AppDevice.fromJson(json['device'] as Map<String, dynamic>),
      );
    } catch (_) {
      return null;
    }
  }
}
