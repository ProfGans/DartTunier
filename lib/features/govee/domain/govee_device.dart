class GoveeDevice {
  const GoveeDevice({
    required this.sku,
    required this.id,
    required this.name,
    required this.supportsRgb,
    required this.supportsTemperature,
  });

  final String sku;
  final String id;
  final String name;
  final bool supportsRgb;
  final bool supportsTemperature;

  factory GoveeDevice.fromJson(Map<String, dynamic> json) {
    final capabilities = (json['capabilities'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item));
    final colorInstances = capabilities
        .where((item) => item['type'] == 'devices.capabilities.color_setting')
        .map((item) => item['instance']);
    final sku = json['sku'] as String? ?? '';
    final id = json['device'] as String? ?? '';
    return GoveeDevice(
      sku: sku,
      id: id,
      name: json['deviceName'] as String? ?? sku,
      supportsRgb: colorInstances.contains('colorRgb'),
      supportsTemperature: colorInstances.contains('colorTemperatureK'),
    );
  }
}
