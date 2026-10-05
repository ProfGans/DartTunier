import 'package:flutter_test/flutter_test.dart';
import 'package:dart_tournament_manager/features/autoscoring/application/autoscore_audio_controller.dart';
import 'package:dart_tournament_manager/features/autoscoring/data/autoscore_audio_output.dart';
import 'package:dart_tournament_manager/features/scorer/application/scorer_audio_controller.dart';
import 'package:dart_tournament_manager/features/scorer/application/scorer_controller.dart';
import 'package:dart_tournament_manager/features/scorer/domain/scorer_settings.dart';
import 'package:dart_tournament_manager/features/scorer/domain/x01/x01_rules.dart';

class _Output implements AutoscoreAudioOutput {
  @override
  Future<void> removal(double volume) async {}
  final effects = <bool>[];
  final speech = <String>[];
  @override
  Future<void> effect(bool bounce, double volume) async {
    effects.add(bounce);
  }

  @override
  Future<void> speak(String text, double volume) async {
    speech.add(text);
  }

  @override
  Future<void> close() async {}
}

void main() {
  test(
    'Third camera dart calls immediately; removal and correction do not repeat it',
    () async {
      final output = _Output();
      final audio = AutoscoreAudioController(output: output);
      final c = ScorerController(
        ScorerSettings(
          participants: const [ScorerParticipant('A'), ScorerParticipant('B')],
        ),
      );
      final bridge = ScorerAudioController(audio, c);
      for (var n = 1; n <= 3; n++) {
        c.throwDart(const X01Rules().createSingle(20));
        bridge.update(c, provisional: true, cameraDarts: n);
        await audio.idle;
        expect(output.speech, n < 3 ? isEmpty : ['60 Punkte']);
      }
      final corrected = c.exportActions();
      corrected.last['label'] = 'T20';
      c.replaceActions(corrected);
      bridge.update(c, provisional: true, cameraDarts: 3);
      bridge.update(c, provisional: false, cameraDarts: 3);
      await audio.idle;
      expect(output.speech, ['60 Punkte']);
      c.throwDart(const X01Rules().createSingle(20));
      bridge.update(c, provisional: true, cameraDarts: 1);
      await audio.idle;
      expect(output.speech.length, 1);
      audio.dispose();
      c.dispose();
    },
  );
  final settings = ScorerSettings(
    startScore: 40,
    bestOfLegs: 1,
    participants: const [ScorerParticipant('A'), ScorerParticipant('B')],
  );
  test(
    'Camera preview sounds once, corrected checkout speaks only on confirmation',
    () async {
      final output = _Output();
      final audio = AutoscoreAudioController(output: output);
      final c = ScorerController(settings);
      final bridge = ScorerAudioController(audio, c);
      c.throwDart(const X01Rules().createSingle(20));
      bridge.update(c, provisional: true);
      c.replaceActions([]);
      c.throwDart(const X01Rules().createDouble(20));
      bridge.update(c, provisional: true);
      await audio.idle;
      expect(output.effects, [false]);
      expect(output.speech, isEmpty);
      bridge.update(c, provisional: false);
      await audio.idle;
      expect(output.speech, ['40 Punkte. Spiel gewonnen.']);
      bridge.update(c, provisional: false);
      c.undo();
      bridge.update(c, provisional: false);
      await audio.idle;
      expect(output.speech.length, 1);
      audio.dispose();
      c.dispose();
    },
  );
  test(
    'Manual scores announce, undo is silent, switches mute output',
    () async {
      final output = _Output();
      final audio = AutoscoreAudioController(output: output);
      final c = ScorerController(settings)..submitScore(20);
      final bridge = ScorerAudioController(audio, c);
      bridge.update(c, provisional: false);
      await audio.idle;
      expect(output.speech, isEmpty);
      c.submitBust();
      bridge.update(c, provisional: false);
      await audio.idle;
      expect(output.speech, ['Überworfen']);
      c.undo();
      bridge.update(c, provisional: false);
      audio.setSounds(false);
      audio.setCaller(false);
      c.submitScore(20);
      bridge.update(c, provisional: false);
      await audio.idle;
      expect(output.speech.length, 1);
      expect(output.effects.length, 1);
      audio.dispose();
      c.dispose();
    },
  );
}
