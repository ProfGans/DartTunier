import 'board_geometry.dart';

/// Short bounded window: agree twice, or commit the observed medoid by frame 3.
/// Never averages across a wire into a position no camera actually proposed.
class TemporalHitDecision {
  final _samples = <FusedHit>[];
  final _supportingViews = <int>[];
  int selectedIndex = -1;
  String reason = 'notEvaluated';
  void reset() {
    _samples.clear();
    _supportingViews.clear();
    selectedIndex = -1;
    reason = 'notEvaluated';
  }

  List<Map<String, Object>> get metrics => [
    for (var i = 0; i < _samples.length; i++)
      {
        'xMillimetres': _samples[i].point.x,
        'yMillimetres': _samples[i].point.y,
        'views': _samples[i].views,
        'supportingViews': _supportingViews[i],
        'residualMillimetres': _samples[i].residual,
      },
  ];
  FusedHit? observe(FusedHit? hit, {int? supportingViews}) {
    if (hit == null) {
      reset();
      return null;
    }
    _samples.add(hit);
    _supportingViews.add(supportingViews ?? hit.views);
    if (_samples.length < 2) {
      reason = 'waitingForSecondFrame';
      return null;
    }
    final previous = _samples[_samples.length - 2];
    if (previous.point.distanceTo(hit.point) <= 2 &&
        BoardGeometry.score(previous.point).label ==
            BoardGeometry.score(hit.point).label) {
      selectedIndex = _samples.length - 1;
      reason = 'consecutiveAgreement';
      return hit;
    }
    if (_samples.length < 3) {
      reason = 'waitingForBoundedSelection';
      return null;
    }
    // A consistent intersection of three independent views carries evidence
    // absent from a repeated two-line fit, whose residual is always zero.
    final supported = [
      for (var i = 0; i < _samples.length; i++)
        if (_supportingViews[i] == 3 && _samples[i].residual <= 3) _samples[i],
    ];
    final ranked = (supported.isEmpty ? _samples : supported).toList()
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
    reason = supported.isEmpty
        ? 'boundedMedoid'
        : 'independentThreeCameraSupport';
    return FusedHit(
      median.point,
      median.residual,
      median.views,
      forcedDecision: true,
    );
  }
}
