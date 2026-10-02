import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/board_geometry.dart';

class AutoscoringStorage {
  static const key = 'autoscoring.calibration.v1';
  Future<Map<String, BoardCalibration>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw == null) return {};
    final json = jsonDecode(raw) as Map<String, dynamic>;
    if (json['version'] != 1) {
      throw const FormatException('Unbekannte Kalibrierungsversion.');
    }
    return {
      for (final entry in (json['cameras'] as Map<String, dynamic>).entries)
        entry.key: BoardCalibration([
          for (final p in entry.value as List)
            Point((p[0] as num).toDouble(), (p[1] as num).toDouble()),
        ]),
    };
  }

  Future<void> save(Map<String, BoardCalibration> cameras) async {
    final prefs = await SharedPreferences.getInstance();
    final ok = await prefs.setString(
      key,
      jsonEncode({
        'version': 1,
        'cameras': {
          for (final entry in cameras.entries)
            entry.key: [
              for (final p in entry.value.points) [p.x, p.y],
            ],
        },
      }),
    );
    if (!ok) throw StateError('Kalibrierung konnte nicht gespeichert werden.');
  }
}
