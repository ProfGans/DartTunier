import 'dart:math';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_tournament_manager/features/autoscoring/domain/board_geometry.dart';
import 'package:dart_tournament_manager/features/autoscoring/domain/boundary_endpoint_contact.dart';
import 'package:dart_tournament_manager/features/autoscoring/domain/dart_tip_detection.dart';
import 'package:dart_tournament_manager/features/autoscoring/domain/frame_detector.dart';

void main() {
  const hit = FusedHit(Point(0, -108), 1, 3);
  const candidate = Point(0.0, -105.0);
  final calibration = BoardCalibration(const [
    Point(.5, .16),
    Point(.84, .5),
    Point(.5, .84),
    Point(.16, .5),
  ]);
  final frame = GrayFrame(100, 100, Uint8List(10000));
  final endpoint = const DartTipObservation(Point(.5, .2), candidate, .95);
  final axis = DartAxis(candidate, candidate + const Point(100, 0));
  final crossing = DartAxis(
    candidate,
    candidate + const Point(0, 100),
    confidence: .6,
  );
  for (final axes in <List<DartAxis?>>[
    [axis, null, null],
    [axis, axis, null],
  ]) {
    test(
      'A lone endpoint without independent nonparallel axes is rejected ${axes[1] != null}',
      () {
        final result = refineBoundaryEndpointContact(
          hit,
          List.filled(3, frame),
          List.filled(3, frame),
          List.filled(3, frame),
          List.filled(3, calibration),
          axes,
          [endpoint, null, null],
        );
        expect(result.hit, same(hit));
        expect(result.metrics['reason'], 'noIndependentAxis');
      },
    );
  }
  test('Independent axes without new contact pixels cannot cross a ring', () {
    final result = refineBoundaryEndpointContact(
      hit,
      List.filled(3, frame),
      List.filled(3, frame),
      List.filled(3, frame),
      List.filled(3, calibration),
      [axis, crossing, null],
      [endpoint, null, null],
    );
    expect(result.hit, same(hit));
    expect(result.metrics['reason'], 'noFreshEndpoint');
  });
}
