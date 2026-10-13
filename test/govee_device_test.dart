import 'package:flutter_test/flutter_test.dart';
import 'package:dart_tournament_manager/features/govee/domain/govee_device.dart';

void main() {
  test('reads supported Govee color controls from device capabilities', () {
    final device = GoveeDevice.fromJson({
      'sku': 'H605C',
      'device': 'AA:BB',
      'deviceName': 'Boardstreifen',
      'capabilities': [
        {'type': 'devices.capabilities.color_setting', 'instance': 'colorRgb'},
        {
          'type': 'devices.capabilities.color_setting',
          'instance': 'colorTemperatureK',
        },
      ],
    });

    expect(device.sku, 'H605C');
    expect(device.id, 'AA:BB');
    expect(device.name, 'Boardstreifen');
    expect(device.supportsRgb, isTrue);
    expect(device.supportsTemperature, isTrue);
  });
}
