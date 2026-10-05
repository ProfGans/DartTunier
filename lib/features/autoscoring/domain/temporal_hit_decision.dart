import 'board_geometry.dart';

/// Short bounded window: agree twice, or commit the observed medoid by frame 3.
/// Never averages across a wire into a position no camera actually proposed.
class TemporalHitDecision {
  final _samples = <FusedHit>[];
  int selectedIndex = -1;
  void reset() {
    _samples.clear();
    selectedIndex = -1;
  }

  List<Map<String, Object>> get metrics => [
    for (final h in _samples)
      {
        'xMillimetres': h.point.x,
        'yMillimetres': h.point.y,
        'views': h.views,
        'residualMillimetres': h.residual,
      },
  ];
  FusedHit? observe(FusedHit? hit) {
    if (hit == null) {
      reset();
      return null;
    }
    _samples.add(hit);
    if (_samples.length < 2) return null;
    final previous = _samples[_samples.length - 2];
    if (previous.point.distanceTo(hit.point) <= 2 &&
        BoardGeometry.score(previous.point).label ==
            BoardGeometry.score(hit.point).label) {
      selectedIndex = _samples.length - 1;
      return hit;
    }
    if (_samples.length < 3) return null;
    final ranked = _samples.toList()
      ..sort(
        (a, b) => _samples
            .fold<double>(0, (s, h) => s + a.point.distanceTo(h.point))
            .compareTo(
              _samples.fold<double>(
                0,
                (s, h) => s + b.point.distanceTo(h.point),
              ),
            ),
      );
    final median = ranked.first;
    selectedIndex = _samples.indexOf(median);
    return FusedHit(
      median.point,
      median.residual,
      median.views,
      forcedDecision: true,
    );
  }
}
