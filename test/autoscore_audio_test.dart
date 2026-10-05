import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_tournament_manager/features/autoscoring/application/autoscore_audio_controller.dart';
import 'package:dart_tournament_manager/features/autoscoring/application/autoscoring_controller.dart';
import 'package:dart_tournament_manager/features/autoscoring/data/autoscore_audio_output.dart';
import 'package:dart_tournament_manager/features/autoscoring/presentation/widgets/autoscore_audio_controls.dart';
import 'package:dart_tournament_manager/features/scorer/domain/x01/x01_rules.dart';

class _Output implements AutoscoreAudioOutput {
  final removals = <double>[];
  @override
  Future<void> removal(double volume) async => removals.add(volume);
  final effects = <bool>[];
  final speech = <String>[];
  Completer<void>? speaking;
  bool closed = false, fail = false;
  @override
  Future<void> effect(bool bounce, double volume) async {
    if (fail) throw StateError('test');
    effects.add(bounce);
  }

  @override
  Future<void> speak(String text, double volume) async {
    speech.add(text);
    await speaking?.future;
  }

  @override
  Future<void> close() async {
    closed = true;
  }
}

void main() {
  test(
    'Removal sound respects effects setting and volume without caller',
    () async {
      final output = _Output();
      final c = AutoscoreAudioController(output: output);
      c.setCaller(false);
      c.setVolume(.4);
      c.confirmRemoval();
      await c.idle;
      expect(output.removals, [.4]);
      expect(output.speech, isEmpty);
      c.setSounds(false);
      c.confirmRemoval();
      await c.idle;
      expect(output.removals, [.4]);
      c.dispose();
    },
  );
  TestWidgetsFlutterBinding.ensureInitialized();
  const previewFont = String.fromEnvironment('LAYOUT_PREVIEW_FONT');
  setUpAll(() async {
    if (previewFont.isNotEmpty) {
      await (FontLoader('Roboto')..addFont(
            File(previewFont).readAsBytes().then(ByteData.sublistView),
          ))
          .load();
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    }
  });
  const rules = X01Rules();
  test(
    'One caller per three darts, bounce is zero, no duplicate on camera updates',
    () async {
      final output = _Output();
      final c = AutoscoreAudioController(output: output);
      addTearDown(c.dispose);
      final darts = [
        rules.createTriple(20),
        AutoscoringController.bouncerThrow,
        rules.createSingle(20),
      ];
      c.update(darts);
      await c.idle;
      c.update(darts);
      await c.idle;
      expect(output.effects, [false, true, false]);
      expect(output.speech, ['80 Punkte']);
      c.update([
        ...darts,
        rules.createTriple(20),
        rules.createTriple(20),
        rules.createTriple(20),
      ]);
      await c.idle;
      expect(output.speech, ['80 Punkte', '180 Punkte']);
      c.update([]);
      c.update(darts);
      await c.idle;
      expect(output.speech.last, '80 Punkte');
      expect(output.speech.length, 3);
    },
  );
  test(
    'Unresolved throws do not announce an invented score; mute keeps counting',
    () async {
      final output = _Output();
      final c = AutoscoreAudioController(output: output);
      addTearDown(c.dispose);
      c.setSounds(false);
      final darts = [
        rules.createSingle(20),
        AutoscoringController.unresolvedThrow,
        rules.createSingle(1),
      ];
      c.update(darts);
      await c.idle;
      expect(output.effects, isEmpty);
      expect(output.speech, ['Treffer bitte korrigieren']);
      c.setCaller(false);
      c.update([]);
      c.update(darts);
      await c.idle;
      expect(output.speech.length, 1);
    },
  );
  test('Hit effects continue while caller is still speaking', () async {
    final output = _Output()..speaking = Completer<void>();
    final c = AutoscoreAudioController(output: output);
    addTearDown(c.dispose);
    final darts = [
      rules.createSingle(20),
      rules.createSingle(20),
      rules.createSingle(20),
    ];
    c.update(darts);
    while (output.speech.isEmpty) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    c.update([...darts, rules.createSingle(1)]);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(output.effects.length, 4);
    output.speaking!.complete();
    await c.idle;
  });
  test(
    'Audio failure does not throw or stop scoring and disposal closes output',
    () async {
      final output = _Output()..fail = true;
      final c = AutoscoreAudioController(output: output);
      c.update([rules.createSingle(20)]);
      await c.idle;
      expect(c.error, isNotNull);
      c.dispose();
      expect(output.closed, isTrue);
    },
  );
  for (final size in [
    const Size(360, 800),
    const Size(800, 600),
    const Size(1440, 900),
  ]) {
    testWidgets('Expanded audio controls at $size and 200% text', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(tester.view.reset);
      final c = AutoscoreAudioController(output: _Output());
      addTearDown(c.dispose);
      final boundary = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          home: RepaintBoundary(
            key: boundary,
            child: Scaffold(
              body: MediaQuery(
                data: MediaQueryData(
                  size: size,
                  textScaler: const TextScaler.linear(2),
                ),
                child: SingleChildScrollView(
                  child: AutoscoreAudioControls(controller: c),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Caller und Sounds'));
      await tester.pumpAndSettle();
      expect(find.byType(SwitchListTile), findsNWidgets(2));
      expect(tester.takeException(), isNull);
      if (previewFont.isNotEmpty) {
        await tester.runAsync(() async {
          final render =
              boundary.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          final image = await render.toImage(pixelRatio: 1);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          image.dispose();
          final file = File(
            'build/layout_previews/autoscore_audio_${size.width.toInt()}.png',
          );
          await file.parent.create(recursive: true);
          await file.writeAsBytes(bytes!.buffer.asUint8List());
        });
      }
    });
  }
}
