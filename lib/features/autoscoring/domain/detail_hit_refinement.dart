import 'board_geometry.dart';
import 'frame_detector.dart';

class DetailHitRefinement {
  const DetailHitRefinement(this.hit, this.axes, this.applied);
  final FusedHit hit;
  final List<DartAxis?> axes;
  final bool applied;
}

/// Revisit only an 80-mm neighbourhood of the provisional tip. A local fit
/// may improve pixel precision, but cannot authorize a large position jump.
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
      hit.point.distanceTo(provisional.point) > 3) {
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
