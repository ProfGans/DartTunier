import 'dart:math';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import '../domain/contact_training_label.dart';

/// Two 32x32 channels: current luminance and signed change, centred on the
/// detector's prediction, never on a manually marked ground-truth endpoint.
Map<String, Object?>? prepareContactModelSample(
  Uint8List currentBytes,
  Uint8List beforeBytes,
  Map label,
  Map<String, double> predictedImagePoint,
) {
  final tip = (label['verifiedImagePoint'] as Map?)?.map(
    (k, v) => MapEntry(k.toString(), (v as num).toDouble()),
  );
  final shaft = [
    for (final p in (label['shaftEndpoints'] as List? ?? []))
      (p as Map).map((k, v) => MapEntry(k.toString(), (v as num).toDouble())),
  ];
  final checked = contactTrainingLabel(
    camera: label['camera'] as int,
    occluded: label['occluded'] as bool?,
    reviewed: label['reviewed'] == true,
    tip: tip,
    shaft: shaft,
  );
  if (checked['trainingEligible'] != true ||
      label['labelSource'] != 'manualOriginalImageReview') {
    return null;
  }
  final current = img.decodeImage(currentBytes),
      before = img.decodeImage(beforeBytes);
  if (current == null || before == null) return null;
  final cx = predictedImagePoint['x']! * (current.width - 1),
      cy = predictedImagePoint['y']! * (current.height - 1);
  if (cx < 32 ||
      cy < 32 ||
      cx >= current.width - 32 ||
      cy >= current.height - 32) {
    return null;
  }
  List<double>? target;
  if (label['occluded'] != true) {
    target = [
      (tip!['x']! * (current.width - 1) - cx + 32) / 2,
      (tip['y']! * (current.height - 1) - cy + 32) / 2,
    ];
    if (target.any((p) => !p.isFinite || p < 0 || p > 31)) return null;
  }
  double gray(img.Pixel p) => (p.r * .299 + p.g * .587 + p.b * .114) / 255;
  final luminance = <double>[], difference = <double>[];
  for (var y = 0; y < 32; y++) {
    for (var x = 0; x < 32; x++) {
      final px = (cx - 32 + 2 * x).round(), py = (cy - 32 + 2 * y).round();
      final oldX = min(
        before.width - 1,
        (px / (current.width - 1) * (before.width - 1)).round(),
      );
      final oldY = min(
        before.height - 1,
        (py / (current.height - 1) * (before.height - 1)).round(),
      );
      final value = gray(current.getPixel(px, py));
      luminance.add(value);
      difference.add(value - gray(before.getPixel(oldX, oldY)));
    }
  }
  return {
    'inputShape': [2, 32, 32],
    'input': [luminance, difference],
    'targetImagePointInPatch': target,
    'occluded': label['occluded'],
    'predictionCentred': true,
  };
}
