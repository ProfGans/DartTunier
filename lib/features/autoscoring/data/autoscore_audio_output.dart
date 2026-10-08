import 'dart:async';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_tts/flutter_tts.dart';

abstract class AutoscoreAudioOutput {
  Future<void> removal(double volume);
  Future<void> effect(bool bounce, double volume);
  Future<void> speak(String text, double volume);
  Future<void> close();
}

class LocalAutoscoreAudioOutput implements AutoscoreAudioOutput {
  LocalAutoscoreAudioOutput() {
    unawaited(_warmEffects());
  }
  FlutterTts? _tts;
  final _effects = <String, AudioPlayer>{};
  final _preparedEffects = <String, Future<AudioPlayer>>{};
  Process? _speech;
  Future<void>? _initializingSpeech;
  bool _closed = false;

  Future<void> _warmEffects() async {
    for (final name in ['hit', 'bounce', 'removal']) {
      if (_closed) return;
      try {
        await _prepareEffect(name);
      } catch (_) {
        // Retry on playback; report unavailable devices through the controller.
      }
    }
  }

  Future<AudioPlayer> _prepareEffect(String name) =>
      _preparedEffects.putIfAbsent(name, () async {
        final player = _effects.putIfAbsent(name, AudioPlayer.new);
        try {
          await player.setReleaseMode(ReleaseMode.stop);
          if (!_closed) {
            await player.setSourceAsset('autoscoring/audio/$name.wav');
          }
          return player;
        } catch (_) {
          _preparedEffects.remove(name);
          rethrow;
        }
      });

  Future<void> _prepareSpeech() => _initializingSpeech ??= () async {
    final tts = _tts = FlutterTts();
    await tts.getLanguages;
    if (_closed) return;
    await tts.setLanguage('de-DE');
    await tts.setSpeechRate(.45);
    await tts.awaitSpeakCompletion(true);
  }();

  @override
  Future<void> effect(bool bounce, double volume) async {
    await _playEffect(bounce ? 'bounce' : 'hit', volume);
  }

  @override
  Future<void> removal(double volume) => _playEffect('removal', volume);

  Future<void> _playEffect(String name, double volume) async {
    if (_closed) return;
    // Effects do not depend on a speech engine being installed.
    final effects = await _prepareEffect(name);
    if (_closed) return;
    await effects.setVolume(volume.clamp(0, 1));
    await effects.seek(Duration.zero);
    if (!_closed) await effects.resume();
  }

  @override
  Future<void> speak(String text, double volume) async {
    if (_closed) return;
    if (Platform.isLinux) {
      final speech = await Process.start('espeak-ng', [
        '-v',
        'de',
        '-s',
        '165',
        '-a',
        '${(volume.clamp(0, 1) * 100).round()}',
        '--stdin',
      ]);
      _speech = speech;
      final output = speech.stdout.drain<void>();
      final errors = speech.stderr.drain<void>();
      try {
        if (_closed) {
          speech.kill();
          return;
        }
        speech.stdin.write(text);
        await speech.stdin.close();
        final code = await speech.exitCode.timeout(const Duration(seconds: 30));
        await Future.wait([output, errors]);
        if (!_closed && code != 0) {
          throw StateError('Linux-Sprachausgabe fehlgeschlagen.');
        }
      } finally {
        speech.kill();
        if (identical(_speech, speech)) _speech = null;
      }
      return;
    }
    await _prepareSpeech();
    if (_closed) return;
    await _tts!.setVolume(volume);
    await _tts!.speak(text);
  }

  @override
  Future<void> close() async {
    _closed = true;
    _speech?.kill();
    try {
      await _initializingSpeech;
    } catch (_) {
      /* No speech bridge. */
    }
    if (_tts != null) {
      try {
        await _tts!.stop();
      } catch (_) {
        /* Device unavailable. */
      }
    }
    for (final prepared in List.of(_preparedEffects.values)) {
      try {
        await prepared;
      } catch (_) {
        // A failed preload still owns a player which needs disposing.
      }
    }
    for (final player in _effects.values) {
      await player.dispose();
    }
  }
}
