import 'package:shared_preferences/shared_preferences.dart';

class AutoscoringPreferences {
  static const _key = 'autoscoring_auto_start_v1';
  Future<bool> load() async =>
      (await SharedPreferences.getInstance()).getBool(_key) ?? false;
  Future<void> save(bool enabled) async {
    if (!await (await SharedPreferences.getInstance()).setBool(_key, enabled)) {
      throw StateError(
        'Autoscoring-Einstellung konnte nicht gespeichert werden',
      );
    }
  }
}
