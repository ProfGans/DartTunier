import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../../../shared/persistence/storage_access.dart';
import '../domain/bot_settings.dart';

class BotSettingsStorage {
  BotSettingsStorage({this.file});
  final File? file;
  Future<File> _file() async =>
      file ??
      File(
        '${(await getApplicationSupportDirectory()).path}${Platform.pathSeparator}scorer_bot_settings.json',
      );
  Future<BotSettings> load() => StorageAccess.run(() async {
    final target = await _file();
    if (!await target.exists()) return const BotSettings();
    final json = jsonDecode(await target.readAsString());
    if (json is! Map<String, dynamic>) {
      throw const FormatException('Ungültige Bot-Einstellungen');
    }
    return BotSettings.fromJson(json);
  });
  Future<void> save(BotSettings settings) => StorageAccess.run(() async {
    final target = await _file();
    await target.parent.create(recursive: true);
    if (await target.exists()) {
      await load();
      await target.copy('${target.path}.bak');
    }
    final temporary = File('${target.path}.tmp');
    await temporary.writeAsString(jsonEncode(settings.toJson()), flush: true);
    await temporary.rename(target.path);
  });
}
