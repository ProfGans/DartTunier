import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_tournament_manager/features/autoscoring/domain/board_geometry.dart';

List<DartAxis> axes(String id) {
  final data = jsonDecode(
    File('test/fixtures/autoscoring/report_$id.json').readAsStringSync(),
  );
  return [
    for (final camera in data['cameras'])
      if (camera['axis'] != null) axis(camera['axis'] as Map),
  ];
}

DartAxis axis(Map data) {
  final a = (data['a'] as num).toDouble(),
      b = (data['b'] as num).toDouble(),
      c = (data['c'] as num).toDouble();
  final start = Point(-a * c, -b * c);
  return DartAxis(
    start,
    start + Point(b, -a),
    confidence: (data['confidence'] as num).toDouble(),
    outerRimOnly: data['outerRimOnly'] as bool,
  );
}

void main() {
  for (final id in ['45', '26', '6']) {
    test(
      'Report $id yields explicitly uncertain estimate from rim observations',
      () {
        final observations = axes(id);
        final hit = decideAxes(observations);
        expect(hit, isNotNull);
        expect(hit!.forcedDecision, isTrue);
        expect(hit.needsReview, isTrue);
        expect(
          hit.point.magnitude,
          lessThanOrEqualTo(BoardGeometry.detectionRadius),
        );
        expect(observations, hasLength(2));
      },
    );
  }
  for (final id in ['32_2', '9', '50']) {
    test('Report $id cannot locate a point with fewer than two axes', () {
      expect(decideAxes(axes(id)), isNull);
    });
  }
  test('Parallel observations cannot produce arbitrary estimated points', () {
    expect(
      decideAxes([
        DartAxis(const Point(0, 0), const Point(1, 0)),
        DartAxis(const Point(0, 10), const Point(1, 10)),
      ]),
      isNull,
    );
  });
}
