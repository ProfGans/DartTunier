import 'dart:math';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_tournament_manager/features/autoscoring/domain/board_geometry.dart';
import 'package:dart_tournament_manager/features/autoscoring/domain/frame_detector.dart';
import 'package:dart_tournament_manager/features/autoscoring/domain/dart_tip_detection.dart';
import 'package:dart_tournament_manager/features/autoscoring/domain/local_segment_boundary.dart';
import 'package:dart_tournament_manager/features/autoscoring/domain/temporal_hit_decision.dart';

void main() {
  test(
    'Two later unverified fits retain a nearby measured boundary contact',
    () {
      final decision = TemporalHitDecision();
      const measured = FusedHit(Point(-16.7, 108.1), 1.2, 2);
      const nominal = FusedHit(Point(-18.5, 109.1), 1.5, 3);
      expect(
        decision.observe(
          measured,
          supportingViews: 2,
          localContactConfirmed: true,
        ),
        isNull,
      );
      expect(decision.observe(nominal, supportingViews: 2), isNull);
      expect(
        decision.observe(nominal, supportingViews: 2)!.point,
        measured.point,
      );
      expect(decision.reason, 'retainedMeasuredContact');
    },
  );
  for (final independent in [false, true]) {
    test(
      'Measured contact cannot replace distant or three-view evidence: $independent',
      () {
        final decision = TemporalHitDecision();
        const measured = FusedHit(Point(-19.3, 126.4), 1.2, 2);
        final other = FusedHit(
          independent ? const Point(-21.4, 128.3) : const Point(40, 50),
          1.3,
          3,
        );
        decision.observe(other, supportingViews: independent ? 3 : 2);
        decision.observe(
          measured,
          supportingViews: 2,
          localContactConfirmed: true,
        );
        final result = decision.observe(
          other,
          supportingViews: independent ? 3 : 2,
        );
        expect(result!.point, other.point);
      },
    );
  }
  test('Measured two-view contact survives nearby unverified medoid', () {
    final decision = TemporalHitDecision();
    const nominal = FusedHit(Point(-21.4, 128.3), 1.3, 3);
    const measured = FusedHit(Point(-19.3, 126.4), 1.2, 2);
    expect(decision.observe(nominal, supportingViews: 2), isNull);
    expect(
      decision.observe(
        measured,
        supportingViews: 2,
        localContactConfirmed: true,
      ),
      isNull,
    );
    expect(
      decision.observe(nominal, supportingViews: 2)!.point,
      measured.point,
    );
    expect(decision.reason, 'retainedMeasuredContact');
    decision.reset();
    expect(decision.observe(nominal, supportingViews: 2), isNull);
    expect(decision.observe(nominal, supportingViews: 2)!.point, nominal.point);
  });
  final calibration = BoardCalibration([
    const Point(.5, .16),
    const Point(.84, .5),
    const Point(.5, .84),
    const Point(.16, .5),
  ]);
  const point = Point(-19.3, 115.85), candidate = Point(-16.85, 115.25);
  final tangent = Point(cos(-pi + pi / 20), sin(-pi + pi / 20));
  GrayFrame image({bool contact = false, bool lowContrast = false}) {
    const size = 700;
    final pixels = Uint8List(size * size);
    for (var y = 0; y < size; y++) {
      for (var x = 0; x < size; x++) {
        final p = calibration.project(Point(x / (size - 1), y / (size - 1)));
        pixels[y * size + x] = lowContrast
            ? 100
            : (p.x * tangent.x + p.y * tangent.y > 0 ? 220 : 30);
        if (contact && p.distanceTo(candidate) < 1.5) {
          pixels[y * size + x] = 255 - pixels[y * size + x];
        }
      }
    }
    return GrayFrame(
      10,
      10,
      Uint8List(100),
      detail: GrayFrame(size, size, pixels),
    );
  }

  test('Sector measurements near triple ring use adjacent single fields', () {
    final nearTriple = Point(
      sin(-pi + pi / 20) * 110,
      -cos(-pi + pi / 20) * 110,
    );
    final measured = measureLocalSegmentBoundary(
      image(),
      calibration,
      nearTriple,
    );
    expect(measured, isNotNull);
    expect(measured!.samples, greaterThanOrEqualTo(4));
    expect(measured.offset.abs(), lessThan(1));
    expect(
      measureLocalSegmentBoundary(
        image(lowContrast: true),
        calibration,
        nearTriple,
      ),
      isNull,
    );
  });

  late GrayFrame empty, occupied;
  setUpAll(() {
    empty = image();
    occupied = image(contact: true);
  });
  test('Measured boundary remains near actual high contrast edge', () {
    final measured = measureLocalSegmentBoundary(empty, calibration, point)!;
    expect(measured.offset.abs(), lessThan(.4));
    expect(measured.samples, greaterThanOrEqualTo(4));
    expect(
      measureLocalSegmentBoundary(image(lowContrast: true), calibration, point),
      isNull,
    );
  });
  for (final supported in [0, 1, 2]) {
    test(
      'Crossing requires new local contact pixels in at least two views: $supported',
      () {
        const provisional = FusedHit(point, 1, 3);
        final result = refineLocalSegmentContact(
          provisional,
          [empty, empty, empty],
          [for (var i = 0; i < 3; i++) i < supported ? occupied : empty],
          [empty, empty, empty],
          [calibration, calibration, calibration],
          [
            for (var i = 0; i < 3; i++)
              DartAxis(
                candidate,
                candidate + const Point(0, 20),
                confidence: .95,
              ),
          ],
          [
            DartTipObservation(
              calibration.unproject(candidate),
              candidate,
              .95,
            ),
            null,
            null,
          ],
        );
        expect(result.metrics['applied'], supported >= 2);
        expect(result.hit.point, supported >= 2 ? candidate : point);
      },
    );
  }
  test('No endpoint or detail means no boundary correction', () {
    const provisional = FusedHit(point, 1, 3);
    expect(
      refineLocalSegmentContact(
        provisional,
        [empty],
        [occupied],
        [empty],
        [calibration],
        [null],
        [null],
      ).hit,
      same(provisional),
    );
    expect(
      measureLocalSegmentBoundary(
        GrayFrame(10, 10, Uint8List(100)),
        calibration,
        point,
      ),
      isNull,
    );
  });
}
