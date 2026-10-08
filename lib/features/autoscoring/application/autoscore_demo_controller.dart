import 'package:flutter/foundation.dart';
import '../../scorer/domain/x01/x01_models.dart';
import '../data/autoscore_diagnostic_export.dart';
import '../domain/board_geometry.dart';
import '../domain/correction_analysis.dart';
import '../data/autoscore_setup_store.dart';
import '../domain/autoscore_setup.dart';

class ReviewedAutoscoreThrow {
  ReviewedAutoscoreThrow(this.detected, this.evidence);
  final DartThrowResult detected;
  final AutoscoreEvidence? evidence;
  String? diagnosticPath;
  bool wasCorrected = false;
  bool ignored = false;
  String? verificationSource;
  AutoscoreSetupThrow? setupThrow;
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
  AutoscoreDemoController({this.setupStore});
  AutoscoreSetupStore? setupStore;
  final _history = <ReviewedAutoscoreThrow>[];
  int _visitStart = 0;
  int _accuracyStart = 0;
  List<ReviewedAutoscoreThrow> get history => List.unmodifiable(_history);
  int get visitStart => _visitStart;
  List<DartThrowResult> get throws => List.unmodifiable(
    _history
        .skip(_visitStart)
        .where((entry) => !entry.ignored)
        .map((entry) => entry.result),
  );
  int get reviewedCount => _history
      .skip(_accuracyStart)
      .where((entry) => entry.actual != null)
      .length;
  int get correctCount =>
      _history.skip(_accuracyStart).where((entry) => entry.correct).length;
  int get uncheckedCount => _history.length - _accuracyStart - reviewedCount;

  /// Restart the displayed measurement without removing throws or diagnoses.
  void resetAccuracy() {
    _accuracyStart = _history.length;
    notifyListeners();
  }

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
    final entry = ReviewedAutoscoreThrow(result, evidence);
    entry.setupThrow = setupStore?.record(
      estimated: evidence?.hit['needsReview'] == true,
      missing: result.label == 'Nicht erkannt',
      bounce: result.label == 'Bouncer',
      detectedLabel: result.label,
    );
    _history.add(entry);
    if (result.label == 'Nicht erkannt') {
      setupStore?.verify(entry.setupThrow, correct: false, missing: true);
    }
    notifyListeners();
  }

  void setImageLabels(int index, List<Map<String, Object?>> labels) {
    _history[index].evidence?.hit['cameraTrainingLabels'] = labels;
    notifyListeners();
  }

  void reset() {
    for (final entry in _history.skip(_visitStart)) {
      if (entry.actual == null) {
        entry.actual = entry.detected;
        entry.verificationSource = 'automaticUntouchedOnRemoval';
      }
      setupStore?.review(entry.setupThrow, corrected: entry.wasCorrected);
    }
    _visitStart = _history.length;
    notifyListeners();
  }

  void review(int index, DartThrowResult actual) {
    _history[index].correctedPoint = null;
    _history[index].actual = actual;
    _history[index].wasCorrected = true;
    _history[index].verificationSource = 'manualCorrection';
    setupStore?.review(_history[index].setupThrow, corrected: true);
    setupStore?.verify(
      _history[index].setupThrow,
      correct: false,
      actualLabel: actual.label,
    );
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
    _history[index].verificationSource = 'manualConfirmation';
    setupStore?.review(_history[index].setupThrow, corrected: false);
    setupStore?.verify(
      _history[index].setupThrow,
      correct: true,
      actualLabel: _history[index].detected.label,
    );
    notifyListeners();
  }

  void markFalsePositive(int index) {
    _history[index].ignored = true;
    review(
      index,
      const DartThrowResult(
        label: 'MISS',
        baseValue: 0,
        scoredPoints: 0,
        isDouble: false,
        isTriple: false,
        isMiss: true,
      ),
    );
    setupStore?.verify(
      _history[index].setupThrow,
      correct: false,
      extra: true,
      actualLabel: 'Kein echter Wurf',
    );
    notifyListeners();
  }
}
