import 'board_geometry.dart';
import 'frame_detector.dart';

class DetailHitRefinement {
  const DetailHitRefinement(this.hit, this.axes, this.applied);
  final FusedHit hit;
  final List<DartAxis?> axes;
  final bool applied;
}

/// Revisit a 35-mm neighbourhood of the provisional tip. Larger corrections
/// require three views with an improved residual and remain bounded to 12 mm.
DetailHitRefinement refineHitDetail(
  FusedHit provisional,
  List<GrayFrame> before,
  List<GrayFrame> current,
  List<BoardCalibration> calibrations,
  List<DartAxis?> axes,
) {
  const detector = FrameDetector();
  if (!List.generate(
    axes.length,
    (i) =>
        axes[i] != null &&
        before[i].detail != null &&
        current[i].detail != null,
  ).any((v) => v)) {
    return DetailHitRefinement(provisional, axes, false);
  }
  final refined = [
    for (var i = 0; i < axes.length; i++)
      axes[i] == null
          ? null
          : detector.refineAxis(
              before[i],
              current[i],
              calibrations[i],
              axes[i]!,
              nearPoint: provisional.point,
            ),
  ];
  final hit = fuseAxes(refined.whereType<DartAxis>().toList());
  if (hit == null ||
      hit.views < provisional.views ||
      hit.residual > 3 ||
      hit.point.distanceTo(provisional.point) >
          (hit.views == 3 && hit.residual < provisional.residual ? 12 : 3)) {
    return DetailHitRefinement(provisional, axes, false);
  }
  final changed = hit.point.distanceTo(provisional.point) > .05;
  return DetailHitRefinement(
    FusedHit(
      hit.point,
      hit.residual,
      hit.views,
      forcedDecision:
          provisional.forcedDecision ||
          BoardGeometry.score(hit.point).label !=
              BoardGeometry.score(provisional.point).label,
    ),
    refined,
    changed,
  );
}
