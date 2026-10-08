import 'package:shared_preferences/shared_preferences.dart';

enum ScorerMonitorStart { off, inApp, window }

class ScorerMonitorPreferences {
  static const key = 'scorer.monitor.start.v1';
  Future<ScorerMonitorStart> load() async {
    final value = (await SharedPreferences.getInstance()).getString(key);
    return ScorerMonitorStart.values.firstWhere(
      (mode) => mode.name == value,
      orElse: () => ScorerMonitorStart.off,
    );
  }

  Future<void> save(ScorerMonitorStart value) async {
    if (!await (await SharedPreferences.getInstance()).setString(
      key,
      value.name,
    )) {
      throw StateError('Einstellung konnte nicht gespeichert werden');
    }
  }
}
