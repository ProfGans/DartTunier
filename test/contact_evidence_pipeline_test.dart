import 'dart:math';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:dart_tournament_manager/features/autoscoring/domain/board_geometry.dart';
import 'package:dart_tournament_manager/features/autoscoring/domain/frame_detector.dart';
import 'package:dart_tournament_manager/features/autoscoring/domain/dart_tip_detection.dart';
import 'package:dart_tournament_manager/features/autoscoring/domain/local_ring_contact.dart';
import 'package:dart_tournament_manager/features/autoscoring/domain/contact_candidate_comparison.dart';
import 'package:dart_tournament_manager/features/autoscoring/domain/contact_training_label.dart';
import 'package:dart_tournament_manager/features/autoscoring/data/contact_model_sample.dart';

void main() {
  final cal = BoardCalibration([
    const Point(.5, .16),
    const Point(.84, .5),
    const Point(.5, .84),
    const Point(.16, .5),
  ]);
  test('Colour distinguishes ring edges with equal luminance', () {
    const size = 700;
    final rgb = img.Image(width: size, height: size);
    for (var y = 0; y < size; y++) {
      for (var x = 0; x < size; x++) {
        final p = cal.project(Point(x / (size - 1), y / (size - 1)));
        if (p.magnitude < 107) {
          rgb.setPixelRgb(x, y, 190, 0, 0);
        } else {
          rgb.setPixelRgb(x, y, 57, 57, 57);
        }
      }
    }
    final detail = GrayFrame(
      size,
      size,
      Uint8List(size * size)..fillRange(0, size * size, 57),
    );
    final grey = GrayFrame(10, 10, Uint8List(100), detail: detail);
    final colour = GrayFrame(
      10,
      10,
      Uint8List(100),
      detail: detail,
      colorImage: img.encodePng(rgb),
    );
    expect(measureLocalRingEdge(grey, cal, const Point(0, -108), 107), isNull);
    expect(
      measureLocalRingEdge(colour, cal, const Point(0, -108), 107),
      closeTo(107, .5),
    );
    // Cached colour measurement must produce the same edge on repeated calls.
    expect(
      measureLocalRingEdge(colour, cal, const Point(0, -108), 107),
      closeTo(107, .5),
    );
  });
  GrayFrame image(
    double ring,
    BoardPoint contact, {
    bool changed = false,
    bool contrast = true,
  }) {
    const size = 700;
    final pixels = Uint8List(size * size);
    for (var y = 0; y < size; y++) {
      for (var x = 0; x < size; x++) {
        final p = cal.project(Point(x / (size - 1), y / (size - 1)));
        var value = contrast
            ? p.magnitude > ring
                  ? 220
                  : 30
            : 100;
        if (changed && p.distanceTo(contact) < 1.5) value = 255 - value;
        pixels[y * size + x] = value;
      }
    }
    return GrayFrame(
      10,
      10,
      Uint8List(100),
      detail: GrayFrame(size, size, pixels),
    );
  }

  for (final radius in [99.0, 107.0, 162.0, 170.0]) {
    test('Measured ring $radius requires two visible contact views', () {
      final candidate = Point(0.0, -radius + 1.5),
          point = Point(0.0, -radius - 1.5);
      final empty = image(radius, candidate),
          current = image(radius, candidate, changed: true);
      final hit = FusedHit(point, 1, 2),
          axis = DartAxis(candidate, candidate + const Point(0, 20));
      final tip = DartTipObservation(cal.unproject(candidate), candidate, .95);
      for (final supported in [1, 2]) {
        final result = refineLocalRingContact(
          hit,
          [empty, empty, empty],
          [current, current, current],
          [empty, empty, empty],
          [cal, cal, cal],
          [axis, axis, axis],
          [tip, if (supported >= 2) tip else null, null],
        );
        expect(result.metrics['applied'], supported >= 2);
        expect(result.hit.point, supported >= 2 ? candidate : point);
      }
      expect(
        refineLocalRingContact(
          FusedHit(point, 1, 3),
          [empty, empty, empty],
          [current, current, current],
          [empty, empty, empty],
          [cal, cal, cal],
          [axis, axis, axis],
          [tip, tip, null],
        ).metrics['applied'],
        false,
      );
      expect(
        measureLocalRingEdge(
          image(radius, candidate, contrast: false),
          cal,
          point,
          radius,
        ),
        isNull,
      );
    });
  }
  test(
    'Shadow comparison downweights suspected existing-dart overlap without changing hit',
    () {
      const point = Point(0.0, -120.0);
      final empty = image(107, point),
          occupied = image(107, point, changed: true);
      const hit = FusedHit(point, 1, 2);
      final result = compareContactCandidates(
        hit,
        [occupied, empty, empty],
        [occupied, occupied, occupied],
        [empty, empty, empty],
        [cal, cal, cal],
        [
          for (var i = 0; i < 3; i++)
            DartAxis(point, point + const Point(0, 20)),
        ],
        [null, null, null],
        [point],
      );
      final row = (result['candidates'] as List).first as Map;
      final views = row['cameras'] as List;
      expect(views[0]['visibility'], 'suspectedOcclusion');
      expect(views[0]['weight'], lessThan(views[1]['weight'] as double));
      expect(result['applied'], false);
      expect(hit.point, point);
      expect(result['candidateCount'], lessThanOrEqualTo(8));
    },
  );
  test(
    'Missing image detail is unknown, never proof of occlusion or contact',
    () {
      final gray = GrayFrame(10, 10, Uint8List(100));
      final result = compareContactCandidates(
        const FusedHit(Point(0, -120), 1, 1),
        [gray],
        [gray],
        [gray],
        [cal],
        [null],
        [null],
        [],
      );
      final view =
          ((result['candidates'] as List).first['cameras'] as List).first;
      expect(view['visibility'], 'missingDetail');
      expect(view['weight'], 0);
    },
  );
  test(
    'Calibration proposals and incomplete image review cannot become training labels',
    () {
      expect(
        contactTrainingLabel(
          camera: 1,
          occluded: false,
          reviewed: false,
          tip: {'x': .5, 'y': .5},
        )['trainingEligible'],
        false,
      );
      expect(
        contactTrainingLabel(
          camera: 1,
          occluded: false,
          reviewed: true,
          tip: {'x': .5, 'y': .5},
        )['trainingEligible'],
        false,
      );
      expect(
        contactTrainingLabel(
          camera: 1,
          occluded: true,
          reviewed: true,
        )['trainingEligible'],
        true,
      );
    },
  );
  test(
    'Training crop is prediction-centred with independent endpoint target',
    () {
      final label = contactTrainingLabel(
        camera: 1,
        occluded: false,
        reviewed: true,
        tip: {'x': .55, 'y': .5},
        shaft: [
          {'x': .5, 'y': .4},
          {'x': .5, 'y': .6},
        ],
      );
      final image = img.Image(width: 128, height: 128);
      img.fill(image, color: img.ColorRgb8(120, 120, 120));
      final bytes = Uint8List.fromList(img.encodePng(image));
      final sample = prepareContactModelSample(bytes, bytes, label, {
        'x': .5,
        'y': .5,
      })!;
      expect(sample['inputShape'], [2, 32, 32]);
      expect((sample['input'] as List)[0], hasLength(1024));
      expect(
        (sample['targetImagePointInPatch'] as List)[0],
        closeTo(19.175, .001),
      );
      expect(
        prepareContactModelSample(
          bytes,
          bytes,
          {...label, 'labelSource': 'calibrationProjection'},
          {'x': .5, 'y': .5},
        ),
        isNull,
      );
    },
  );
}
