import 'dart:typed_data';
import 'dart:math';
import 'package:dart_tournament_manager/features/autoscoring/domain/board_geometry.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_tournament_manager/features/autoscoring/domain/automatic_visit_reset.dart';
import 'package:dart_tournament_manager/features/autoscoring/domain/frame_detector.dart';

GrayFrame frame({int brightness = 80, int shafts = 0, int noise = 0}) {
  final pixels = Uint8List(10000)..fillRange(0, 10000, brightness);
  for (var shaft = 0; shaft < shafts; shaft++) {
    for (var x = 0; x < 100; x++) {
      pixels[2000 + shaft * 200 + x] = brightness + 100;
    }
  }
  for (var i = 0; i < noise; i++) {
    pixels[8000 + i] = brightness + 100;
  }
  return GrayFrame(100, 100, pixels);
}

void main() {
  test('A hand covering old shafts cannot release an unfinished visit', () {
    final reset = AutomaticVisitReset();
    final empty = List.generate(3, (_) => frame());
    final occupied = List.generate(3, (_) => frame(shafts: 1));
    reset.observe(
      empty: empty,
      occupied: occupied,
      current: empty,
      stable: false,
      darts: 1,
    );
    final hand = GrayFrame(
      100,
      100,
      Uint8List(10000)..fillRange(0, 10000, 220),
    );
    for (var n = 0; n < 5; n++) {
      reset.observe(
        empty: empty,
        occupied: occupied,
        current: List.filled(3, hand),
        stable: true,
        darts: 1,
      );
    }
    expect(reset.waitingForEmpty, true);
  });
  for (final darts in [1, 2, 3]) {
    test(
      'Shifted old shafts plus new dart release only unfinished visit $darts',
      () {
        final reset = AutomaticVisitReset();
        final empty = List.generate(3, (_) => frame());
        final occupied = List.generate(3, (_) => frame(shafts: darts));
        reset.observe(
          empty: empty,
          occupied: occupied,
          current: empty,
          stable: false,
          darts: darts,
        );
        final shifted = List.generate(3, (_) {
          final pixels = Uint8List.fromList(frame(shafts: darts + 1).pixels);
          for (var shaft = 0; shaft < darts; shaft++) {
            pixels.fillRange(2000 + shaft * 200, 2100 + shaft * 200, 80);
            pixels.fillRange(2100 + shaft * 200, 2200 + shaft * 200, 180);
          }
          return GrayFrame(100, 100, pixels);
        });
        for (var n = 0; n < 4; n++) {
          reset.observe(
            empty: empty,
            occupied: occupied,
            current: shifted,
            stable: true,
            darts: darts,
          );
        }
        expect(reset.waitingForEmpty, darts == 3);
      },
    );
  }
  test('Unrelated added pixels cannot replace a removed shaft', () {
    final reset = AutomaticVisitReset();
    final empty = List.generate(3, (_) => frame());
    final occupied = List.generate(3, (_) => frame(shafts: 2));
    for (var n = 0; n < 8; n++) {
      reset.observe(
        empty: empty,
        occupied: occupied,
        current: List.generate(3, (_) => frame(shafts: 1, noise: 200)),
        stable: true,
        darts: 2,
      );
      if (n == 0) {
        // Prime the latch with an unambiguous partial removal first.
        reset.observe(
          empty: empty,
          occupied: occupied,
          current: List.generate(3, (_) => frame(shafts: 1)),
          stable: true,
          darts: 2,
        );
      }
    }
    expect(reset.waitingForEmpty, true);
  });
  for (final darts in [1, 2, 3]) {
    test(
      'Restored full occupied board unlocks only unfinished visit $darts',
      () {
        final reset = AutomaticVisitReset();
        final empty = List.generate(3, (_) => frame());
        final occupied = List.generate(3, (_) => frame(shafts: darts));
        reset.observe(
          empty: empty,
          occupied: occupied,
          current: empty,
          stable: false,
          darts: darts,
        );
        expect(reset.waitingForEmpty, true);
        for (var n = 0; n < 4; n++) {
          reset.observe(
            empty: empty,
            occupied: occupied,
            current: occupied,
            stable: true,
            darts: darts,
          );
        }
        expect(reset.waitingForEmpty, darts == 3);
      },
    );
  }
  test('A remaining dart cannot release a genuine partial-removal latch', () {
    final reset = AutomaticVisitReset();
    final empty = List.generate(3, (_) => frame());
    final occupied = List.generate(3, (_) => frame(shafts: 2));
    final partial = List.generate(3, (_) => frame(shafts: 1));
    for (var n = 0; n < 8; n++) {
      reset.observe(
        empty: empty,
        occupied: occupied,
        current: partial,
        stable: true,
        darts: 2,
      );
    }
    expect(reset.waitingForEmpty, true);
  });
  test(
    'Changed background outside the calibrated board cannot block removal',
    () {
      final reset = AutomaticVisitReset();
      final calibration = BoardCalibration(const [
        Point(.5, .2),
        Point(.8, .5),
        Point(.5, .8),
        Point(.2, .5),
      ]);
      GrayFrame board(bool dart, bool background) {
        final pixels = Uint8List(10000)..fillRange(0, 10000, 80);
        for (var x = 40; x < 60; x++) {
          if (dart) pixels[50 * 100 + x] = 200;
        }
        if (background) pixels.fillRange(0, 1000, 200);
        return GrayFrame(100, 100, pixels);
      }

      var state = VisitResetState.playing;
      for (var i = 0; i < 6; i++) {
        state = reset.observe(
          empty: List.generate(3, (_) => board(false, false)),
          occupied: List.generate(3, (_) => board(true, false)),
          current: List.generate(3, (_) => board(false, true)),
          stable: false,
          darts: 3,
          calibrations: List.filled(3, calibration),
        );
        if (state == VisitResetState.cleared) break;
      }
      expect(state, VisitResetState.cleared);
    },
  );

  for (final remaining in [false, true]) {
    test('Contrast change after removal; remaining shaft: $remaining', () {
      final reset = AutomaticVisitReset();
      GrayFrame textured(int darts, bool exposure) {
        final pixels = Uint8List(10000);
        for (var p = 0; p < pixels.length; p++) {
          final base = 40 + (p % 5) * 32;
          var value = base;
          if (p >= 2000 && p < 2000 + darts * 100) value = base + 70;
          pixels[p] = exposure
              ? (value * 1.3 + 8).round().clamp(0, 255)
              : value;
        }
        return GrayFrame(100, 100, pixels);
      }

      var state = VisitResetState.playing;
      for (var i = 0; i < 6; i++) {
        state = reset.observe(
          empty: List.generate(3, (_) => textured(0, false)),
          occupied: List.generate(3, (_) => textured(3, false)),
          current: List.generate(3, (_) => textured(remaining ? 1 : 0, true)),
          stable: false,
          darts: 3,
        );
        if (state == VisitResetState.cleared) break;
      }
      expect(
        state,
        remaining ? VisitResetState.waitingForEmpty : VisitResetState.cleared,
      );
    });
  }

  test('Sparse old-shaft compression residuals do not lock an empty board', () {
    final reset = AutomaticVisitReset();
    final pixels = Uint8List.fromList(frame().pixels);
    for (var p = 2000; p < 2020; p++) {
      pixels[p] = 180;
    }
    final current = GrayFrame(100, 100, pixels);
    var state = VisitResetState.playing;
    for (var i = 0; i < 6; i++) {
      state = reset.observe(
        empty: List.generate(3, (_) => frame()),
        occupied: List.generate(3, (_) => frame(shafts: 3)),
        current: List.filled(3, current),
        stable: true,
        darts: 3,
      );
      if (state == VisitResetState.cleared) break;
    }
    expect(state, VisitResetState.cleared);
  });

  for (final noise in [0, 40]) {
    test('Removal clears with exposure shift and $noise unrelated pixels', () {
      final reset = AutomaticVisitReset();
      final empty = List.generate(3, (_) => frame());
      final occupied = List.generate(3, (_) => frame(shafts: 3));
      var state = VisitResetState.playing;
      for (var i = 0; i < 6; i++) {
        state = reset.observe(
          empty: empty,
          occupied: occupied,
          current: List.generate(
            3,
            (_) => frame(brightness: i.isEven ? 115 : 85, noise: noise),
          ),
          stable: false,
          darts: 3,
        );
        if (state == VisitResetState.cleared) break;
      }
      expect(state, VisitResetState.cleared);
    });
  }
  test('One remaining shaft in any camera prevents clearing', () {
    final reset = AutomaticVisitReset();
    for (var i = 0; i < 10; i++) {
      expect(
        reset.observe(
          empty: List.generate(3, (_) => frame()),
          occupied: List.generate(3, (_) => frame(shafts: 3)),
          current: [frame(), frame(), frame(brightness: 115, shafts: 1)],
          stable: true,
          darts: 3,
        ),
        VisitResetState.waitingForEmpty,
      );
    }
  });
  test('Hand and brightness change alone do not clear occupied darts', () {
    final reset = AutomaticVisitReset();
    for (var i = 0; i < 6; i++) {
      expect(
        reset.observe(
          empty: List.generate(3, (_) => frame()),
          occupied: List.generate(3, (_) => frame(shafts: 3)),
          current: List.generate(3, (_) => frame(brightness: 115, shafts: 3)),
          stable: true,
          darts: 3,
        ),
        VisitResetState.waitingForEmpty,
      );
    }
    final hand = GrayFrame(
      100,
      100,
      Uint8List(10000)..fillRange(0, 10000, 220),
    );
    for (var i = 0; i < 6; i++) {
      expect(
        reset.observe(
          empty: List.generate(3, (_) => frame()),
          occupied: List.generate(3, (_) => frame(shafts: 3)),
          current: [hand, hand, hand],
          stable: true,
          darts: 3,
        ),
        VisitResetState.waitingForEmpty,
      );
    }
  });
}
