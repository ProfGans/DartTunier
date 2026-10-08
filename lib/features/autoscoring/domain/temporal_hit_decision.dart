import 'board_geometry.dart';

/// Short bounded window: agree twice, or commit the observed medoid by frame 3.
/// Never averages across a wire into a position no camera actually proposed.
class TemporalHitDecision {
  final _samples = <FusedHit>[];
  final _supportingViews = <int>[];
  final _localContacts = <bool>[];
  int selectedIndex = -1;
  String reason = 'notEvaluated';
  void reset() {
    _samples.clear();
    _supportingViews.clear();
    _localContacts.clear();
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
  FusedHit? observe(
    FusedHit? hit, {
    int? supportingViews,
    List<BoardPoint> contactPoints = const [],
    bool localContactConfirmed = false,
  }) {
    if (hit == null) {
      reset();
      return null;
    }
    _samples.add(hit);
    _supportingViews.add(supportingViews ?? hit.views);
    _localContacts.add(localContactConfirmed);
    if (_samples.length < 2) {
      reason = 'waitingForSecondFrame';
      return null;
    }
    final previous = _samples[_samples.length - 2];
    // A remaining visible endpoint can corroborate an earlier intersection.
    // Repeated one-camera estimates must not erase that independent evidence.
    final retained = [
      for (var i = 0; i < _samples.length - 1; i++)
        if (hit.views == 1 &&
            _samples[i].views >= 2 &&
            _supportingViews[i] >= 2 &&
            _samples[i].residual <= 3 &&
            _samples[i].point.distanceTo(hit.point) <= 15 &&
            contactPoints.any((p) => p.distanceTo(_samples[i].point) <= 4))
          i,
    ];
    if (_samples.length >= 3 && retained.isNotEmpty) {
      retained.sort(
        (a, b) => _supportingViews[b].compareTo(_supportingViews[a]),
      );
      selectedIndex = retained.first;
      reason = 'retainedMultiviewContact';
      final chosen = _samples[selectedIndex];
      return FusedHit(
        chosen.point,
        chosen.residual,
        chosen.views,
        forcedDecision: true,
      );
    }
    // Do not discard a measured boundary contact just because two later
    // unverified shaft fits agree. Keep the bounded three-frame decision;
    // independently supported three-camera evidence still takes precedence.
    final retainMeasured =
        _samples.length >= 3 &&
        !_supportingViews.asMap().entries.any(
          (e) => e.value == 3 && _samples[e.key].residual <= 3,
        ) &&
        List.generate(_samples.length - 1, (i) => i).any(
          (i) =>
              _localContacts[i] &&
              _supportingViews[i] >= 2 &&
              _samples[i].point.distanceTo(hit.point) <= 4,
        );
    if (!retainMeasured &&
        previous.point.distanceTo(hit.point) <= 2 &&
        retained.isEmpty &&
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
    final local = [
      for (var i = 0; i < _samples.length; i++)
        if (_localContacts[i] &&
            _supportingViews[i] >= 2 &&
            hit.point.distanceTo(_samples[i].point) <= 4)
          _samples[i],
    ];
    final ranked =
        (supported.isNotEmpty
                ? supported
                : local.isNotEmpty
                ? local
                : _samples)
            .toList()
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
    reason = supported.isNotEmpty
        ? 'independentThreeCameraSupport'
        : local.isNotEmpty
        ? 'retainedMeasuredContact'
        : 'boundedMedoid';
    return FusedHit(
      median.point,
      median.residual,
      median.views,
      forcedDecision: true,
    );
  }
}
