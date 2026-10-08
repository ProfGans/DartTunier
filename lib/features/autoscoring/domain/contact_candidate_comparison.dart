import 'dart:math';
import 'board_geometry.dart';
import 'dart_tip_detection.dart';
import 'frame_detector.dart';
import 'local_segment_boundary.dart';

/// Bounded image-evidence comparison; shadow mode never changes the scorer.
Map<String, Object?> compareContactCandidates(
  FusedHit hit,
  List<GrayFrame> before,
  List<GrayFrame> current,
  List<GrayFrame> empty,
  List<BoardCalibration> calibrations,
  List<DartAxis?> axes,
  List<DartTipObservation?> tips,
  List<BoardPoint> existing,
) {
  final candidates = <BoardPoint>[hit.point];
  void add(BoardPoint p) {
    if (p.magnitude <= BoardGeometry.detectionRadius &&
        p.distanceTo(hit.point) <= 20 &&
        candidates.every((c) => c.distanceTo(p) > 1) &&
        candidates.length < 8) {
      candidates.add(p);
    }
  }

  for (final tip in tips.whereType<DartTipObservation>()) {
    add(tip.board);
  }
  for (var i = 0; i < axes.length; i++) {
    for (var j = i + 1; j < axes.length; j++) {
      if (axes[i] == null || axes[j] == null) continue;
      final p = fuseAxes([axes[i]!, axes[j]!]);
      if (p != null) add(p.point);
    }
  }
  final rows = <Map<String, Object?>>[];
  for (final candidate in candidates) {
    final views = <Map<String, Object?>>[];
    var score = 0.0, supported = 0;
    for (var i = 0; i < current.length; i++) {
      final fresh = localContactChangeCount(
        before[i],
        current[i],
        calibrations[i],
        candidate,
      );
      final occupied = localContactChangeCount(
        empty[i],
        before[i],
        calibrations[i],
        candidate,
      );
      final hasDetail = before[i].detail != null && current[i].detail != null;
      final overlap =
          occupied >= 6 &&
          fresh < 6 &&
          existing.any((p) => p.distanceTo(candidate) <= 12);
      final quality = !hasDetail
          ? .0
          : overlap
          ? .25
          : fresh >= 6
          ? 1.0
          : .4;
      final tip = tips[i];
      final endpointDistance = tip?.board.distanceTo(candidate);
      final axisDistance = axes[i]?.distance(candidate);
      final localScore =
          min(1.0, fresh / 20) +
          (endpointDistance == null ? 0 : max(0.0, 1 - endpointDistance / 6)) +
          (axisDistance == null
              ? 0
              : max(0.0, 1 - axisDistance / 4) * axes[i]!.confidence);
      score += quality * localScore;
      if (fresh >= 6 && axisDistance != null && axisDistance <= 3) supported++;
      views.add({
        'camera': i + 1,
        'newContactPixels': fresh,
        'previouslyOccupiedPixels': occupied,
        'visibility': !hasDetail
            ? 'missingDetail'
            : overlap
            ? 'suspectedOcclusion'
            : fresh >= 6
            ? 'newContactVisible'
            : 'insufficientEvidence',
        'weight': quality,
        'endpointDistanceMillimetres': endpointDistance,
        'axisDistanceMillimetres': axisDistance,
      });
    }
    rows.add({
      'xMillimetres': candidate.x,
      'yMillimetres': candidate.y,
      'label': BoardGeometry.score(candidate).label,
      'score': score,
      'supportingViews': supported,
      'cameras': views,
    });
  }
  final ranked = List<Map<String, Object?>>.of(rows)
    ..sort((a, b) => (b['score'] as double).compareTo(a['score'] as double));
  return {
    'mode': 'shadow',
    'candidateSource': 'currentFrameBeforeTemporalSelection',
    'applied': false,
    'occlusionIsEstimate': true,
    'candidateCount': rows.length,
    'candidates': rows,
    'preferred': (ranked.first['score'] as double) > 0 ? ranked.first : null,
    'margin': ranked.length < 2
        ? null
        : (ranked[0]['score'] as double) - (ranked[1]['score'] as double),
  };
}
