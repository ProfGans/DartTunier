import 'dart:convert';
import 'calibration_codec.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/board_geometry.dart';

class AutoscoringStorage {
  static const key = 'autoscoring.calibration.v1';
  Future<Map<String, BoardCalibration>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw == null) return {};
    final json = jsonDecode(raw) as Map<String, dynamic>;
    if (json['version'] != 1 && json['version'] != 2) {
      throw const FormatException('Unbekannte Kalibrierungsversion.');
    }
    return {
      for (final entry in (json['cameras'] as Map<String, dynamic>).entries)
        entry.key: decodeCalibration(entry.value),
    };
  }

  Future<void> save(Map<String, BoardCalibration> cameras) async {
    final prefs = await SharedPreferences.getInstance();
    final ok = await prefs.setString(
      key,
      jsonEncode({
        'version': 2,
        'cameras': {
          for (final entry in cameras.entries)
            entry.key: encodeCalibration(entry.value),
        },
      }),
    );
    if (!ok) throw StateError('Kalibrierung konnte nicht gespeichert werden.');
  }
}
