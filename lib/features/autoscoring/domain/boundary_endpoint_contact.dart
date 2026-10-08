import 'dart:math';
import 'board_geometry.dart';
import 'dart_tip_detection.dart';
import 'frame_detector.dart';
import 'local_ring_contact.dart';
import 'local_segment_boundary.dart';

/// Recover a visible contact when another camera ends at an occluded shaft.
/// A nearby endpoint alone is insufficient: two nonparallel axes, independent
/// empty-board edge measurements and a contradicted contact view are required.
LocalSegmentContactDecision refineBoundaryEndpointContact(
  FusedHit hit,
  List<GrayFrame> before,
  List<GrayFrame> current,
  List<GrayFrame> empty,
  List<BoardCalibration> calibrations,
  List<DartAxis?> axes,
  List<DartTipObservation?> tips,
) {
  final metrics = <String, Object?>{'applied': false};
  LocalSegmentContactDecision unchanged(String reason) {
    metrics['reason'] = reason;
    return LocalSegmentContactDecision(hit, metrics);
  }

  if (!BoardGeometry.nearWire(hit.point, tolerance: 4)) {
    return unchanged('notBoundary');
  }
  final candidates = <int>[
    for (var i = 0; i < tips.length; i++)
      if (tips[i] != null &&
          tips[i]!.confidence >= .85 &&
          tips[i]!.board.distanceTo(hit.point) <= 4 &&
          BoardGeometry.score(tips[i]!.board).label !=
              BoardGeometry.score(hit.point).label)
        i,
  ];
  if (candidates.length != 1) return unchanged('noUniqueEndpoint');
  final view = candidates.single, candidate = tips[view]!.board;
  final supporting = <int>[
    for (var i = 0; i < axes.length; i++)
      if (axes[i] != null &&
          axes[i]!.confidence >= .45 &&
          axes[i]!.distance(candidate) <= 3)
        i,
  ];
  if (supporting.length < 2 ||
      !supporting.contains(view) ||
      !supporting.any(
        (i) =>
            (axes[i]!.a * axes[view]!.b - axes[view]!.a * axes[i]!.b).abs() >=
            .35,
      )) {
    return unchanged('noIndependentAxis');
  }
  if (localContactChangeCount(
        before[view],
        current[view],
        calibrations[view],
        candidate,
      ) <
      6) {
    return unchanged('noFreshEndpoint');
  }
  final contradicted = <int>[
    for (var i = 0; i < tips.length; i++)
      if (i != view &&
          tips[i] != null &&
          tips[i]!.board.distanceTo(candidate) > 8 &&
          localContactChangeCount(
                before[i],
                current[i],
                calibrations[i],
                candidate,
              ) <
              4)
        i,
  ];
  if (contradicted.isEmpty) return unchanged('noOccludedContact');
  final original = BoardGeometry.score(hit.point),
      proposed = BoardGeometry.score(candidate);
  final edges = <Object?>[];
  var edgeSupport = 0;
  if (original.baseValue == proposed.baseValue) {
    final rings = [
      99.0,
      107.0,
      162.0,
      170.0,
    ].where((r) => (r - hit.point.magnitude).abs() <= 4).toList();
    if (rings.length != 1 ||
        (hit.point.magnitude - rings.single) *
                (candidate.magnitude - rings.single) >=
            0) {
      return unchanged('notUniqueRingCrossing');
    }
    for (var i = 0; i < empty.length; i++) {
      final edge = measureLocalRingEdge(
        empty[i],
        calibrations[i],
        candidate,
        rings.single,
      );
      edges.add(edge);
      if (edge != null &&
          (candidate.magnitude - edge) * (candidate.magnitude - rings.single) >
              0 &&
          (candidate.magnitude - edge).abs() >= .5) {
        edgeSupport++;
      }
    }
  } else {
    if (original.isDouble != proposed.isDouble ||
        original.isTriple != proposed.isTriple) {
      return unchanged('multipleBoundaryCrossing');
    }
    final angle = atan2(hit.point.x, -hit.point.y);
    final boundary =
        ((angle - pi / 20) / (pi / 10)).round() * pi / 10 + pi / 20;
    final tangent = Point(cos(boundary), sin(boundary));
    final signed = candidate.x * tangent.x + candidate.y * tangent.y;
    for (var i = 0; i < empty.length; i++) {
      final edge = measureLocalSegmentBoundary(
        empty[i],
        calibrations[i],
        hit.point,
      );
      edges.add(edge?.toJson());
      if (edge != null &&
          edge.spread <= 1 &&
          (signed - edge.offset) * signed > 0 &&
          (signed - edge.offset).abs() >= .25) {
        edgeSupport++;
      }
    }
  }
  metrics.addAll({
    'endpointCamera': view,
    'axisCameras': supporting,
    'occludedCameras': contradicted,
    'measuredEdges': edges,
    'edgeSupport': edgeSupport,
  });
  if (edgeSupport < 2) return unchanged('insufficientEdgeSupport');
  metrics.addAll({
    'applied': true,
    'reason': 'visibleEndpointIndependentAxisAndEdges',
  });
  return LocalSegmentContactDecision(
    FusedHit(candidate, hit.residual, 2, forcedDecision: true),
    metrics,
  );
}
