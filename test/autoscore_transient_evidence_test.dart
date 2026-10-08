import 'dart:math';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_tournament_manager/features/autoscoring/domain/automatic_bounce_detector.dart';
import 'package:dart_tournament_manager/features/autoscoring/domain/recent_shaft_evidence.dart';
import 'package:dart_tournament_manager/features/autoscoring/domain/frame_detector.dart';
import 'package:dart_tournament_manager/features/autoscoring/domain/board_geometry.dart';

void main() {
  GrayFrame frame(int changed, {int? time}) => GrayFrame(
    100,
    100,
    Uint8List(10000)..fillRange(0, changed, 100),
    timestampUs: time,
  );
  final references = [frame(0), frame(0), frame(0)];
  final shaft = DartAxis(
    const Point(0, -100),
    const Point(0, -50),
    confidence: .95,
  );
  test(
    'Blurred bounce requires two settled observations after a transient',
    () {
      final detector = AutomaticBounceDetector();
      bool observe(
        int time,
        List<int> changes, {
        bool stable = true,
        List<DartAxis> axes = const [],
      }) => detector.observe(
        reference: references,
        current: changes.map((n) => frame(n)).toList(),
        axes: axes,
        stable: stable,
        nowMilliseconds: time,
      );
      expect(observe(0, [50, 220, 70], stable: false), false);
      expect(observe(30, [50, 80, 50]), false);
      expect(observe(60, [50, 80, 50]), true);
      expect(detector.metrics['reason'], 'transientWithoutPersistentShaft');
      expect(observe(90, [50, 80, 50]), false);
      detector.reset();
      expect(detector.metrics, isEmpty);
    },
  );
  for (final kind in ['shaft', 'motion', 'expired', 'large']) {
    test('Transient does not count a bounce with $kind evidence', () {
      final detector = AutomaticBounceDetector();
      detector.observe(
        reference: references,
        current: [frame(50), frame(220), frame(70)],
        axes: [],
        stable: false,
        nowMilliseconds: 0,
      );
      for (var n = 1; n <= 3; n++) {
        expect(
          detector.observe(
            reference: references,
            current: [
              frame(50),
              frame(
                kind == 'large'
                    ? 1000
                    : kind == 'motion'
                    ? 210
                    : 80,
              ),
              frame(50),
            ],
            axes: kind == 'shaft' ? [shaft] : [],
            stable: true,
            nowMilliseconds: kind == 'expired' ? 1000 + n * 30 : n * 30,
          ),
          false,
        );
      }
    });
  }
  test('Shaft alternatives expire and never cross occupied references', () {
    final history = RecentShaftEvidence();
    List<GrayFrame> frames(int time) =>
        List.generate(3, (_) => frame(0, time: time));
    history.observe(references, frames(0), [shaft, null, null]);
    history.observe(references, frames(50000), [null, null, null]);
    expect(history.alternatives([[], [], []]).first, [shaft]);
    history.observe(references, frames(100001), [null, null, null]);
    expect(history.alternatives([[], [], []]).first, isEmpty);
    history.observe(references, frames(110000), [shaft, null, null]);
    history.observe(
      [frame(0), references[1], references[2]],
      frames(120000),
      [null, null, null],
    );
    expect(history.alternatives([[], [], []]).first, isEmpty);
    history.observe(references, frames(130000), [shaft, null, null]);
    history.observe(references, frames(120000), [null, null, null]);
    expect(history.alternatives([[], [], []]).first, isEmpty);
  });
}
