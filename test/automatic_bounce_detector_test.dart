import 'dart:math';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_tournament_manager/features/autoscoring/domain/automatic_bounce_detector.dart';
import 'package:dart_tournament_manager/features/autoscoring/domain/board_geometry.dart';
import 'package:dart_tournament_manager/features/autoscoring/domain/frame_detector.dart';

void main() {
  final empty = List.generate(3, (_) => GrayFrame(100, 100, Uint8List(10000)));
  final changed = List.generate(3, (_) {
    final p = Uint8List(10000);
    p.fillRange(5000, 5050, 180);
    return GrayFrame(100, 100, p);
  });
  final axes = [
    DartAxis(const Point(-100, -103), const Point(100, -103)),
    DartAxis(const Point(0, -170), const Point(0, 100)),
  ];
  test(
    'Short two-camera shaft appearance and return yields exactly one bounce',
    () {
      final detector = AutomaticBounceDetector();
      expect(
        detector.observe(
          reference: empty,
          current: changed,
          axes: axes,
          stable: false,
          nowMilliseconds: 0,
        ),
        isFalse,
      );
      expect(
        detector.observe(
          reference: empty,
          current: empty,
          axes: [],
          stable: false,
          nowMilliseconds: 100,
        ),
        isFalse,
      );
      expect(
        detector.observe(
          reference: empty,
          current: empty,
          axes: [],
          stable: true,
          nowMilliseconds: 1100,
        ),
        isTrue,
      );
      expect(
        detector.observe(
          reference: empty,
          current: empty,
          axes: [],
          stable: true,
          nowMilliseconds: 1200,
        ),
        isFalse,
      );
    },
  );
  test('Hand motion, slow removal, and reset do not produce bounces', () {
    final detector = AutomaticBounceDetector();
    detector.observe(
      reference: empty,
      current: changed,
      axes: [],
      stable: false,
      nowMilliseconds: 0,
    );
    expect(
      detector.observe(
        reference: empty,
        current: empty,
        axes: [],
        stable: true,
        nowMilliseconds: 100,
      ),
      isFalse,
    );
    detector.observe(
      reference: empty,
      current: changed,
      axes: axes,
      stable: false,
      nowMilliseconds: 200,
    );
    expect(
      detector.observe(
        reference: empty,
        current: empty,
        axes: [],
        stable: true,
        nowMilliseconds: 1500,
      ),
      isFalse,
    );
    detector.observe(
      reference: empty,
      current: changed,
      axes: axes,
      stable: false,
      nowMilliseconds: 2000,
    );
    detector.reset();
    expect(
      detector.observe(
        reference: empty,
        current: empty,
        axes: [],
        stable: true,
        nowMilliseconds: 2100,
      ),
      isFalse,
    );
  });
}
