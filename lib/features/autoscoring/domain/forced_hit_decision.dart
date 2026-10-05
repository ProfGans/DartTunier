import 'dart:math';
import 'board_geometry.dart';

/// Last resort after stable, localized evidence of a new dart. Motion pixels
/// include the shaft above the board, so this is explicitly an uncertain hit.
FusedHit forceHitDecision(List<DartAxis> axes, List<List<BoardPoint>> changes) {
  final intersection = decideAxes(axes);
  if (intersection != null) return intersection;
  final samples = changes
      .map(
        (view) => view
            .where(
              (p) =>
                  p.x.isFinite &&
                  p.y.isFinite &&
                  p.magnitude <= BoardGeometry.detectionRadius,
            )
            .toList(),
      )
      .where((view) => view.isNotEmpty)
      .toList();
  // No invented bull location when spatial evidence is unavailable.
  if (samples.isEmpty) {
    return FusedHit(
      const Point(220.0, 0.0),
      230,
      axes.length,
      forcedDecision: true,
    );
  }
  var best = samples.first.first;
  var bestCost = double.infinity;
  final priors = [
    for (final view in samples)
      [
        for (var i = 0; i < view.length; i += max(1, (view.length / 40).ceil()))
          view[i],
      ],
  ];
  void search(
    double left,
    double top,
    double right,
    double bottom,
    double step,
  ) {
    for (var y = top; y <= bottom; y += step) {
      for (var x = left; x <= right; x += step) {
        final p = Point(x, y);
        if (p.magnitude > BoardGeometry.detectionRadius) continue;
        var cost = 0.0;
        for (final axis in axes) {
          final distance = axis.distance(p);
          cost += distance * distance * axis.confidence * axis.confidence;
        }
        // A weak spatial prior resolves parallel/single axes without declaring
        // the centre of the board a hit. Each camera gets equal weight.
        for (final view in priors) {
          var nearest = double.infinity;
          for (final q in view) {
            final dx = x - q.x, dy = y - q.y;
            nearest = min(nearest, dx * dx + dy * dy);
          }
          cost += nearest * .02;
        }
        if (cost < bestCost) {
          bestCost = cost;
          best = p;
        }
      }
    }
  }

  search(-230, -230, 230, 230, 8);
  final coarse = best;
  search(coarse.x - 8, coarse.y - 8, coarse.x + 8, coarse.y + 8, 1);
  final residual = axes.isEmpty
      ? 230.0
      : axes.fold<double>(0, (sum, axis) => sum + axis.distance(best)) /
            axes.length;
  return FusedHit(best, residual, axes.length, forcedDecision: true);
}
