import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dart_tournament_manager/features/autoscoring/data/calibration_reference_storage.dart';
import 'package:dart_tournament_manager/features/autoscoring/domain/board_geometry.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'Versioned references retain the two latest images and their calibration',
    () async {
      const storage = CalibrationReferenceStorage();
      final calibration = BoardCalibration(const [
        Point(.5, .1),
        Point(.9, .5),
        Point(.5, .9),
        Point(.1, .5),
      ]);
      for (var i = 1; i <= 3; i++) {
        await storage.remember(Uint8List.fromList([i]), calibration);
      }
      final references = await storage.load();
      expect(references.map((r) => r.image.single), [2, 3]);
      expect(references.first.calibration.points, calibration.points);
      final prefs = await SharedPreferences.getInstance();
      expect(
        (jsonDecode(prefs.getString(CalibrationReferenceStorage.key)!)
            as Map)['version'],
        2,
      );
    },
  );
  test(
    'Unknown reference schema is ignored without loading camera transforms',
    () async {
      SharedPreferences.setMockInitialValues({
        CalibrationReferenceStorage.key: jsonEncode({'version': 2}),
      });
      expect(await const CalibrationReferenceStorage().load(), isEmpty);
    },
  );
}
