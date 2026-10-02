import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/board_geometry.dart';

class CalibrationReference {
  const CalibrationReference(this.image, this.calibration);
  final Uint8List image;
  final BoardCalibration calibration;
}

/// Independently versioned printed-ring references, never camera transforms
/// reused blindly after a camera moves. Every image is geometrically refitted.
class CalibrationReferenceStorage {
  const CalibrationReferenceStorage();
  static const key = 'autoscoring.reference.v1';
  Future<List<CalibrationReference>> load() async {
    final raw = (await SharedPreferences.getInstance()).getString(key);
    if (raw == null) return [];
    final json = jsonDecode(raw) as Map<String, dynamic>;
    if (json['version'] != 1 || json['geometryRevision'] != 1) return [];
    return [
      for (final r in json['references'] as List)
        CalibrationReference(
          base64Decode(r['image'] as String),
          BoardCalibration([
            for (final p in r['points'] as List)
              Point((p[0] as num).toDouble(), (p[1] as num).toDouble()),
          ]),
        ),
    ];
  }

  Future<void> remember(Uint8List image, BoardCalibration calibration) async {
    final references = await load();
    references.add(CalibrationReference(image, calibration));
    while (references.length > 2) {
      references.removeAt(0);
    }
    await (await SharedPreferences.getInstance()).setString(
      key,
      jsonEncode({
        'version': 1,
        'geometryRevision': 1,
        'references': [
          for (final r in references)
            {
              'image': base64Encode(r.image),
              'points': [
                for (final p in r.calibration.points) [p.x, p.y],
              ],
            },
        ],
      }),
    );
  }
}
