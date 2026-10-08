import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_tournament_manager/features/autoscoring/domain/frame_detector.dart';
import 'package:dart_tournament_manager/features/autoscoring/domain/observation_latency.dart';

void main() {
  test('Latency includes repeated confirmation frames and resets per dart', () {
    final tracker = ObservationLatency();
    final references = [
      for (var i = 0; i < 3; i++) GrayFrame(1, 1, Uint8List(1)),
    ];
    List<GrayFrame> frames(int time) => [
      for (var i = 0; i < 3; i++)
        GrayFrame(1, 1, Uint8List(1), timestampUs: time + i),
    ];
    expect(
      tracker.observe(
        references,
        frames(1000),
        shaftEvidence: false,
      )['shaftEvidenceToCurrentCaptureMilliseconds'],
      null,
    );
    expect(
      tracker.observe(
        references,
        frames(2000),
        shaftEvidence: true,
      )['shaftEvidenceToCurrentCaptureMilliseconds'],
      0,
    );
    expect(
      tracker.observe(
        references,
        frames(702000),
        shaftEvidence: true,
      )['shaftEvidenceToCurrentCaptureMilliseconds'],
      700,
    );
    expect(
      tracker.observe(references, frames(702000), shaftEvidence: true),
      isEmpty,
    );
    final next = List.of(references)..[1] = GrayFrame(1, 1, Uint8List(1));
    expect(
      tracker.observe(
        next,
        frames(750000),
        shaftEvidence: false,
      )['shaftEvidenceToCurrentCaptureMilliseconds'],
      null,
    );
    expect(
      tracker.observe(
        next,
        frames(760000),
        shaftEvidence: true,
      )['shaftEvidenceToCurrentCaptureMilliseconds'],
      0,
    );
  });
}
