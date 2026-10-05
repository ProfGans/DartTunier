import 'package:flutter/foundation.dart';
import '../../scorer/domain/x01/x01_models.dart';
import '../data/autoscore_diagnostic_export.dart';
import '../domain/board_geometry.dart';
import '../domain/correction_analysis.dart';

class ReviewedAutoscoreThrow {
  ReviewedAutoscoreThrow(this.detected, this.evidence);
  final DartThrowResult detected;
  final AutoscoreEvidence? evidence;
  String? diagnosticPath;
  bool wasCorrected = false;
  bool get estimated => !wasCorrected && evidence?.hit['needsReview'] == true;
  DartThrowResult? actual;
  BoardPoint? correctedPoint;
  BoardPoint? get detectedPoint {
    final x = evidence?.hit['xMillimetres'], y = evidence?.hit['yMillimetres'];
    return x is num && y is num ? BoardPoint(x.toDouble(), y.toDouble()) : null;
  }

  BoardPoint? get point => correctedPoint ?? detectedPoint;
  DartThrowResult get result => actual ?? detected;
  bool get correct => actual != null && !wasCorrected;
}

class AutoscoreDemoController extends ChangeNotifier {
  final _history = <ReviewedAutoscoreThrow>[];
  int _visitStart = 0;
  List<ReviewedAutoscoreThrow> get history => List.unmodifiable(_history);
  int get visitStart => _visitStart;
  List<DartThrowResult> get throws => List.unmodifiable(
    _history.skip(_visitStart).map((entry) => entry.result),
  );
  int get reviewedCount =>
      _history.where((entry) => entry.actual != null).length;
  int get correctCount => _history.where((entry) => entry.correct).length;
  double? get accuracyPercent =>
      reviewedCount == 0 ? null : 100 * correctCount / reviewedCount;
  int get totalPoints => throws.fold(0, (sum, dart) => sum + dart.scoredPoints);
  Map<String, Object?> get correctionAnalysis => analysePositionCorrections([
    for (final entry in _history)
      if (entry.correctedPoint != null)
        PositionCorrectionSample(entry.correctedPoint!, entry.detectedPoint, [
          for (final camera
              in entry.evidence?.cameras ?? <AutoscoreCameraEvidence>[])
            (camera.metadata['axis'] as Map?)?.cast<String, Object?>(),
        ]),
  ]);

  void add(DartThrowResult result, {AutoscoreEvidence? evidence}) {
    _history.add(ReviewedAutoscoreThrow(result, evidence));
    notifyListeners();
  }

  void reset() {
    for (final entry in _history.skip(_visitStart)) {
      entry.actual ??= entry.detected;
    }
    _visitStart = _history.length;
    notifyListeners();
  }

  void review(int index, DartThrowResult actual) {
    _history[index].correctedPoint = null;
    _history[index].actual = actual;
    _history[index].wasCorrected = true;
    _history[index].diagnosticPath = null;
    notifyListeners();
  }

  void movePoint(int index, BoardPoint point) {
    if (!point.x.isFinite ||
        !point.y.isFinite ||
        point.magnitude > BoardGeometry.detectionRadius) {
      return;
    }
    review(index, BoardGeometry.score(point));
    _history[index].correctedPoint = point;
    notifyListeners();
  }

  void confirm(int index) {
    if (_history[index].wasCorrected) return;
    _history[index].actual = _history[index].detected;
    notifyListeners();
  }
}
