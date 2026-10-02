import 'package:shared_preferences/shared_preferences.dart';

class UpdateChannelPreferences {
  static const key = 'updates.v1.include_prereleases';
  Future<bool> load() async =>
      (await SharedPreferences.getInstance()).getBool(key) ?? false;
  Future<void> save(bool enabled) async {
    if (!await (await SharedPreferences.getInstance()).setBool(key, enabled)) {
      throw StateError('Update-Kanal konnte nicht gespeichert werden.');
    }
  }
}
