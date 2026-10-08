import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_tournament_manager/features/autoscoring/domain/board_geometry.dart';
import 'package:dart_tournament_manager/features/autoscoring/domain/frame_detector.dart';
import 'package:dart_tournament_manager/features/autoscoring/domain/shaft_frame_stability.dart';

void main() {
  test('Stable shaft permits slight motion only in fresh matching frames', () {
    final stability = ShaftFrameStability();
    final reference = GrayFrame(1, 1, Uint8List(1));
    final axis = DartAxis(const BoardPoint(1, 0), const BoardPoint(1, 100));
    GrayFrame frame(int time) =>
        GrayFrame(1, 1, Uint8List(1), timestampUs: time);
    expect(stability.observe(0, reference, frame(10000), axis, .003), false);
    expect(stability.observe(0, reference, frame(43000), axis, .003), true);
    expect(stability.observe(1, reference, frame(43000), axis, .003), false);
    expect(stability.observe(0, reference, frame(43000), axis, .003), false);
    expect(stability.observe(0, reference, frame(200000), axis, .003), false);
    expect(
      stability.observe(
        0,
        GrayFrame(1, 1, Uint8List(1)),
        frame(230000),
        axis,
        .003,
      ),
      false,
    );
  });
  for (final failure in ['motion', 'shift', 'angle', 'confidence', 'missing']) {
    test('Reject unstable observation: $failure', () {
      final stability = ShaftFrameStability();
      final reference = GrayFrame(1, 1, Uint8List(1));
      final axis = DartAxis(const BoardPoint(1, 0), const BoardPoint(1, 100));
      GrayFrame frame(int time) =>
          GrayFrame(1, 1, Uint8List(1), timestampUs: time);
      stability.observe(0, reference, frame(10000), axis, .003);
      final candidate = switch (failure) {
        'shift' => DartAxis(const BoardPoint(2, 0), const BoardPoint(2, 100)),
        'angle' => DartAxis(const BoardPoint(1, 0), const BoardPoint(3, 100)),
        'confidence' => DartAxis(
          const BoardPoint(1, 0),
          const BoardPoint(1, 100),
          confidence: .85,
        ),
        'missing' => null,
        _ => axis,
      };
      expect(
        stability.observe(
          0,
          reference,
          frame(43000),
          candidate,
          failure == 'motion' ? .02 : .003,
        ),
        false,
      );
    });
  }
}
