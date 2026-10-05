import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../scorer/domain/x01/x01_models.dart';
import '../data/autoscore_audio_output.dart';
import '../data/autoscore_setup_store.dart';

class AutoscoreAudioController extends ChangeNotifier {
  AutoscoreAudioController({AutoscoreAudioOutput? output, this.setupStore})
    : output = output ?? LocalAutoscoreAudioOutput() {
    setupStore?.addListener(_settingsChanged);
    _settingsChanged();
  }
  final AutoscoreSetupStore? setupStore;
  void _settingsChanged() {
    final store = setupStore;
    if (store == null || !store.loaded || _disposed) return;
    final setup = store.active;
    if (caller == setup.caller &&
        sounds == setup.sounds &&
        volume == setup.volume) {
      return;
    }
    caller = setup.caller;
    sounds = setup.sounds;
    volume = setup.volume;
    notifyListeners();
  }

  final AutoscoreAudioOutput output;
  bool caller = true, sounds = true;
  double volume = .7;
  String? error;
  int _lastCount = 0;
  bool _disposed = false;
  Future<void> _queue = Future.value();
  Future<void> _effectQueue = Future.value();

  void update(List<DartThrowResult> throws, {int Function()? scoreProvider}) {
    if (_disposed) return;
    if (throws.length < _lastCount) _lastCount = 0;
    for (var index = _lastCount; index < throws.length; index++) {
      final dart = throws[index];
      final playEffect = sounds;
      final callScore = caller && (index + 1) % 3 == 0;
      final batch = callScore
          ? throws.sublist(index - 2, index + 1)
          : <DartThrowResult>[];
      final uncertain = batch.any((d) => d.label == 'Nicht erkannt');
      final points = callScore
          ? (index == throws.length - 1 && scoreProvider != null
                ? scoreProvider()
                : batch.fold<int>(0, (sum, d) => sum + d.scoredPoints))
          : 0;
      final effect = playEffect
          ? _effect(() async {
              if (sounds) await output.effect(dart.label == 'Bouncer', volume);
            })
          : Future<void>.value();
      if (callScore) {
        _send(() async {
          await effect;
          if (_disposed) return;
          if (callScore && caller) {
            if (playEffect && sounds) {
              await Future<void>.delayed(const Duration(milliseconds: 160));
            }
            if (_disposed) return;
            await output.speak(
              uncertain ? 'Treffer bitte korrigieren' : '$points Punkte',
              volume,
            );
          }
        });
      }
    }
    _lastCount = throws.length;
  }

  void setCaller(bool value) {
    caller = value;
    setupStore?.saveSettings(caller: value);
    notifyListeners();
  }

  void setSounds(bool value) {
    sounds = value;
    setupStore?.saveSettings(sounds: value);
    notifyListeners();
  }

  void setVolume(double value) {
    volume = value.clamp(0, 1);
    setupStore?.saveSettings(volume: volume);
    notifyListeners();
  }

  void testEffect(bool bounce) {
    _effect(() => output.effect(bounce, volume));
  }

  void testCaller() => _send(() => output.speak('180 Punkte', volume));
  void playHit({bool bounce = false}) {
    if (sounds) {
      _effect(() async {
        if (sounds) await output.effect(bounce, volume);
      });
    }
  }

  void announce(String text) {
    if (caller) {
      _send(() async {
        if (caller) await output.speak(text, volume);
      });
    }
  }

  void confirmRemoval() {
    if (sounds) {
      _effect(() async {
        if (sounds) await output.removal(volume);
      });
    }
  }

  void _send(Future<void> Function() action) {
    _queue = _queue.then((_) async {
      if (_disposed) return;
      try {
        await action();
      } catch (_) {
        if (!_disposed) {
          error =
              'Audioausgabe nicht verfügbar. Lautsprecher und installierte deutsche Stimme prüfen.';
          notifyListeners();
        }
      }
    });
  }

  Future<void> _effect(Future<void> Function() action) {
    _effectQueue = _effectQueue.then((_) async {
      if (_disposed) return;
      try {
        await action();
      } catch (_) {
        if (!_disposed) {
          error = 'Treffersound nicht verfügbar. Audioausgabe prüfen.';
          notifyListeners();
        }
      }
    });
    return _effectQueue;
  }

  @visibleForTesting
  Future<void> get idle async {
    await Future.wait([_queue, _effectQueue]);
  }

  @override
  void dispose() {
    setupStore?.removeListener(_settingsChanged);
    _disposed = true;
    unawaited(output.close().catchError((Object _) {}));
    super.dispose();
  }
}
