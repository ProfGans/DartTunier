import '../domain/board_geometry.dart';
import '../domain/lens_distortion.dart';

Map<String, Object> encodeCalibration(BoardCalibration calibration) => {
  'points': [
    for (final p in calibration.points) [p.x, p.y],
  ],
  'lens': calibration.lens.toJson(),
};

BoardCalibration decodeCalibration(Object? value) {
  final points = value is List ? value : (value as Map)['points'] as List;
  final lens = value is Map && value['lens'] is Map
      ? LensDistortion.fromJson(value['lens'] as Map)
      : const LensDistortion();
  return BoardCalibration([
    for (final p in points)
      BoardPoint((p[0] as num).toDouble(), (p[1] as num).toDouble()),
  ], lens: lens);
}
