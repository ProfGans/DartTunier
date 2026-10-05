import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/autoscore_setup.dart';
import '../domain/verification_summary.dart';

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
  final _statisticsGenerations = <String, int>{};
  final _verificationEvents = <Map<String, Object?>>[];
  int _eventCounter = 0;
  final _validationSeries = <String, String>{};
  final _validationAttempts = <String, int>{};
  List<AutoscoreSetup> get setups => List.unmodifiable(_setups);
  AutoscoreSetup get active => _setups.firstWhere((s) => s.id == _activeId);
  Future<void> load() => _loading ??= _load();
  Future<void> _load() async {
    try {
      final raw = (await SharedPreferences.getInstance()).getString(key);
      if (raw != null) {
        final json = jsonDecode(raw) as Map<String, dynamic>;
        if (json['version'] != 1 && json['version'] != 2) {
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
        final events = [
          for (final event in json['verificationEvents'] as List? ?? [])
            Map<String, Object?>.from(event as Map),
        ];
        final series = Map<String, String>.from(
          json['validationSeries'] as Map? ?? {},
        );
        final attempts = Map<String, int>.from(
          json['validationAttempts'] as Map? ?? {},
        );
        if (attempts.values.any((count) => count < 0)) {
          throw const FormatException('Ungültige Prüfserie');
        }
        _setups = items;
        _verificationEvents.addAll(
          events.skip(events.length > 5000 ? events.length - 5000 : 0),
        );
        _validationSeries.addAll(series);
        _validationAttempts.addAll(attempts);
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
      'version': 2,
      'activeId': _activeId,
      'setups': [for (final setup in _setups) setup.toJson()],
      'verificationEvents': _verificationEvents,
      'validationSeries': _validationSeries,
      'validationAttempts': _validationAttempts,
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
    String detectedLabel = '',
  }) {
    if (!loaded) return null;
    active.total++;
    if (estimated) active.estimated++;
    if (missing) active.missing++;
    if (bounce) active.bouncers++;
    final token = AutoscoreSetupThrow(
      active.id,
      statisticsGeneration: _statisticsGenerations[active.id] ?? 0,
    );
    token.detectedLabel = detectedLabel;
    token.eventId =
        '${DateTime.now().microsecondsSinceEpoch}-${_eventCounter++}';
    token.validationSeriesId = _validationSeries[active.id];
    if (token.validationSeriesId != null) {
      _validationAttempts[active.id] =
          (_validationAttempts[active.id] ?? 0) + 1;
    }
    _save();
    return token;
  }

  void review(AutoscoreSetupThrow? token, {required bool corrected}) {
    if (token == null ||
        !loaded ||
        token.review == AutoscoreReview.incorrect ||
        token.statisticsGeneration !=
            (_statisticsGenerations[token.setupId] ?? 0)) {
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

  void resetStatistics(String setupId) {
    if (!loaded) return;
    final index = _setups.indexWhere((s) => s.id == setupId);
    if (index < 0) return;
    final setup = _setups[index];
    setup.total = setup.correct = setup.incorrect = 0;
    setup.estimated = setup.missing = setup.bouncers = 0;
    setup.verifiedCorrect = setup.verifiedIncorrect = setup.verifiedMissing =
        setup.verifiedExtra = 0;
    _verificationEvents.removeWhere((e) => e['setupId'] == setupId);
    _validationSeries.remove(setupId);
    _validationAttempts.remove(setupId);
    // Late reviews of pre-reset darts must not refill or subtract new counters.
    _statisticsGenerations[setupId] =
        (_statisticsGenerations[setupId] ?? 0) + 1;
    _save();
  }

  void verify(
    AutoscoreSetupThrow? token, {
    required bool correct,
    String? actualLabel,
    bool missing = false,
    bool extra = false,
  }) {
    if (!loaded ||
        token == null ||
        token.statisticsGeneration !=
            (_statisticsGenerations[token.setupId] ?? 0)) {
      return;
    }
    final next = correct ? AutoscoreReview.correct : AutoscoreReview.incorrect;
    if (token.verification == AutoscoreReview.incorrect && correct) return;
    final setup = _setups.firstWhere((s) => s.id == token.setupId);
    if (token.verification != next) {
      if (token.verification == AutoscoreReview.correct) {
        setup.verifiedCorrect--;
      }
      if (correct) {
        setup.verifiedCorrect++;
      } else {
        setup.verifiedIncorrect++;
      }
      token.verification = next;
    }
    if (!correct && missing && !token.verifiedMissing) {
      setup.verifiedMissing++;
      token.verifiedMissing = true;
    }
    if (!correct && extra && !token.verifiedExtra) {
      setup.verifiedExtra++;
      token.verifiedExtra = true;
    }
    final event = <String, Object?>{
      'eventId': token.eventId,
      'setupId': token.setupId,
      'verifiedAtUtc': DateTime.now().toUtc().toIso8601String(),
      'detected': token.detectedLabel,
      'actual': actualLabel,
      'correct': correct,
      'missing': token.verifiedMissing,
      'extra': token.verifiedExtra,
      'verificationSource': 'explicitUserReview',
    };
    event['validationSeriesId'] = token.validationSeriesId;
    final index = _verificationEvents.indexWhere(
      (e) => e['eventId'] == token.eventId,
    );
    if (index < 0) {
      _verificationEvents.add(event);
    } else {
      _verificationEvents[index] = event;
    }
    if (_verificationEvents.length > 5000) _verificationEvents.removeAt(0);
    _save();
  }

  String exportVerification(String setupId) {
    final setup = _setups.firstWhere((s) => s.id == setupId);
    final validation = validationSummary(setupId);
    return const JsonEncoder.withIndent('  ').convert({
      'schemaVersion': 1,
      'exportedAtUtc': DateTime.now().toUtc().toIso8601String(),
      'setupId': setup.id,
      'setupName': setup.name,
      'verifiedCorrect': setup.verifiedCorrect,
      'verifiedIncorrect': setup.verifiedIncorrect,
      'verifiedMissing': setup.verifiedMissing,
      'verifiedExtra': setup.verifiedExtra,
      'independentAccuracyPercent': setup.independentAccuracy,
      'notIndependentlyReviewed': setup.total - setup.independentlyReviewed,
      'events': _verificationEvents
          .where((e) => e['setupId'] == setupId)
          .toList(),
      'eventHistoryLimit': 5000,
      'targetAccuracyPercent': 99.5,
      'validationSeriesId': _validationSeries[setupId],
      'validationAttempts': validation.attempts,
      'validationReviewed': validation.reviewed,
      'validationAccuracyPercent': validation.accuracyPercent,
      'oneSided95PercentLowerBound': validation.lowerBoundPercent,
      'targetSupportedByReviewedSeries': validation.supportsTarget,
      'targetStatus':
          'Nur eine vollständig geprüfte, repräsentative und von Entwicklungsdaten getrennte Testserie ist aussagekräftig.',
    });
  }

  void startValidationSeries(String setupId) {
    if (!loaded || !_setups.any((s) => s.id == setupId)) return;
    _validationSeries[setupId] = DateTime.now().toUtc().toIso8601String();
    _validationAttempts[setupId] = 0;
    _save();
  }

  VerificationSummary validationSummary(String setupId) {
    final series = _validationSeries[setupId];
    final events = series == null
        ? <Map<String, Object?>>[]
        : _verificationEvents
              .where(
                (e) =>
                    e['setupId'] == setupId &&
                    e['validationSeriesId'] == series,
              )
              .toList();
    return VerificationSummary(
      _validationAttempts[setupId] ?? 0,
      events.where((e) => e['correct'] == true).length,
      events.where((e) => e['correct'] == false).length,
    );
  }
}
