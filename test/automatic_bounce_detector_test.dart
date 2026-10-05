import 'dart:math';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_tournament_manager/features/autoscoring/domain/automatic_bounce_detector.dart';
import 'package:dart_tournament_manager/features/autoscoring/domain/board_geometry.dart';
import 'package:dart_tournament_manager/features/autoscoring/domain/frame_detector.dart';

void main() {
  for (final radius in [215.0, 245.0]) {
    test('Weak outer bounce at $radius mm counts once after returning', () {
      final reference = List.generate(
        3,
        (_) => GrayFrame(100, 100, Uint8List(10000)),
      );
      final transient = List.generate(3, (_) {
        final pixels = Uint8List(10000)..fillRange(5000, 5050, 22);
        return GrayFrame(100, 100, pixels);
      });
      final detector = AutomaticBounceDetector();
      expect(
        detector.observe(
          reference: reference,
          current: transient,
          axes: [
            DartAxis(
              Point(-50, -radius),
              Point(50, -radius),
              outerRimOnly: true,
            ),
            DartAxis(Point(0, -280), Point(0, -180), outerRimOnly: true),
          ],
          stable: false,
          nowMilliseconds: 0,
        ),
        isFalse,
      );
      expect(
        detector.observe(
          reference: reference,
          current: reference,
          axes: [],
          stable: true,
          nowMilliseconds: 150,
        ),
        isTrue,
      );
      expect(
        detector.observe(
          reference: reference,
          current: reference,
          axes: [],
          stable: true,
          nowMilliseconds: 250,
        ),
        isFalse,
      );
    });
  }
  test(
    'Single view and parallel transient axes cannot count an outer bounce',
    () {
      final reference = List.generate(
        3,
        (_) => GrayFrame(100, 100, Uint8List(10000)),
      );
      final transient = List.generate(
        3,
        (_) => GrayFrame(100, 100, Uint8List(10000)..fillRange(5000, 5050, 22)),
      );
      for (final axes in [
        [DartAxis(const Point(-50, -215), const Point(50, -215))],
        [
          DartAxis(const Point(-50, -215), const Point(50, -215)),
          DartAxis(const Point(-50, -220), const Point(50, -220)),
        ],
      ]) {
        final detector = AutomaticBounceDetector();
        detector.observe(
          reference: reference,
          current: transient,
          axes: axes,
          stable: false,
          nowMilliseconds: 0,
        );
        expect(
          detector.observe(
            reference: reference,
            current: reference,
            axes: [],
            stable: true,
            nowMilliseconds: 100,
          ),
          isFalse,
        );
      }
    },
  );
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
