import '../domain/frame_detector.dart';
import '../domain/board_geometry.dart';

typedef CameraAnalysisInput = ({
  GrayFrame previous,
  GrayFrame reference,
  GrayFrame frame,
  BoardCalibration calibration,
});
typedef CameraAnalysis = ({
  double changeFraction,
  DartAxis? axis,
  List<BoardPoint> changedPixels,
});

List<CameraAnalysis> analyzeCameraFrames(List<CameraAnalysisInput> cameras) {
  const detector = FrameDetector();
  return [
    for (final c in cameras)
      (
        changeFraction: detector.changedFraction(c.previous, c.frame),
        axis: detector.axis(c.reference, c.frame, c.calibration),
        changedPixels: detector.changeSamples(
          c.reference,
          c.frame,
          c.calibration,
        ),
      ),
  ];
}
