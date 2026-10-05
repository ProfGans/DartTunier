import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/autoscore_setup.dart';

class AutoscoreSetupStore extends ChangeNotifier {
  static final instance = AutoscoreSetupStore();
  static const key = 'autoscoring.setups.v1';
  List<AutoscoreSetup> _setups = [
    AutoscoreSetup(id: 'default', name: 'Standard-Setup'),
  ];
  String _activeId = 'default';
  bool loaded = false;
  bool _disposed = false;
  String? error;
  Future<void>? _loading;
  Future<void> _writes = Future.value();
  List<AutoscoreSetup> get setups => List.unmodifiable(_setups);
  AutoscoreSetup get active => _setups.firstWhere((s) => s.id == _activeId);
  Future<void> load() => _loading ??= _load();
  Future<void> _load() async {
    try {
      final raw = (await SharedPreferences.getInstance()).getString(key);
      if (raw != null) {
        final json = jsonDecode(raw) as Map<String, dynamic>;
        if (json['version'] != 1) {
          throw const FormatException('Unbekannte Setup-Version');
        }
        final items = (json['setups'] as List)
            .map(
              (s) =>
                  AutoscoreSetup.fromJson(Map<String, dynamic>.from(s as Map)),
            )
            .toList();
        if (items.isEmpty ||
            items.map((s) => s.id).toSet().length != items.length) {
          throw const FormatException('Ungültige Setup-Liste');
        }
        _setups = items;
        _activeId = items.any((s) => s.id == json['activeId'])
            ? json['activeId'] as String
            : items.first.id;
      }
      loaded = true;
      error = null;
    } catch (_) {
      error =
          'Setups konnten nicht geladen werden. Gespeicherte Daten bleiben erhalten.';
    }
    if (!_disposed) notifyListeners();
  }

  void _save() {
    if (!loaded) return;
    final snapshot = jsonEncode({
      'version': 1,
      'activeId': _activeId,
      'setups': [for (final setup in _setups) setup.toJson()],
    });
    _writes = _writes.then((_) async {
      try {
        if (!await (await SharedPreferences.getInstance()).setString(
          key,
          snapshot,
        )) {
          throw StateError('Speichern fehlgeschlagen');
        }
        error = null;
      } catch (_) {
        error = 'Setup-Statistik konnte nicht gespeichert werden.';
      }
      if (!_disposed) notifyListeners();
    });
    notifyListeners();
  }

  Future<void> flush() => _writes;
  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void select(String id) {
    if (!loaded || !_setups.any((s) => s.id == id)) return;
    _activeId = id;
    _save();
  }

  void create(String name) {
    if (!loaded || name.trim().isEmpty) return;
    final setup = AutoscoreSetup(
      id: 'setup-${DateTime.now().microsecondsSinceEpoch}-${_setups.length}',
      name: name.trim(),
      cameraKeys: List.of(active.cameraKeys),
      caller: active.caller,
      sounds: active.sounds,
      volume: active.volume,
    );
    _setups.add(setup);
    _activeId = setup.id;
    _save();
  }

  void rename(String name) {
    if (!loaded || name.trim().isEmpty) return;
    active.name = name.trim();
    _save();
  }

  void saveSettings({
    List<String>? cameras,
    bool? caller,
    bool? sounds,
    double? volume,
  }) {
    if (!loaded) return;
    if (cameras != null) active.cameraKeys = List.of(cameras);
    if (caller != null) active.caller = caller;
    if (sounds != null) active.sounds = sounds;
    if (volume != null) active.volume = volume.clamp(0, 1);
    _save();
  }

  AutoscoreSetupThrow? record({
    bool estimated = false,
    bool missing = false,
    bool bounce = false,
  }) {
    if (!loaded) return null;
    active.total++;
    if (estimated) active.estimated++;
    if (missing) active.missing++;
    if (bounce) active.bouncers++;
    final token = AutoscoreSetupThrow(active.id);
    _save();
    return token;
  }

  void review(AutoscoreSetupThrow? token, {required bool corrected}) {
    if (token == null || !loaded || token.review == AutoscoreReview.incorrect) {
      return;
    }
    final next = corrected
        ? AutoscoreReview.incorrect
        : AutoscoreReview.correct;
    if (token.review == next) return;
    final setup = _setups.firstWhere((s) => s.id == token.setupId);
    if (token.review == AutoscoreReview.correct) setup.correct--;
    if (corrected) {
      setup.incorrect++;
    } else {
      setup.correct++;
    }
    token.review = next;
    _save();
  }
}
