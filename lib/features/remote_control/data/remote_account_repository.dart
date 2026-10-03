import 'package:supabase_flutter/supabase_flutter.dart';
import '../../accounts/data/supabase_account_config.dart';
import '../../devices/domain/app_device.dart';
import '../domain/account_remote_device.dart';

/// Session secrets are fetched over authenticated HTTPS; never send login tokens over LAN.
class RemoteAccountRepository {
  SupabaseClient? get _client =>
      SupabaseAccountBootstrap.isInitialized ? Supabase.instance.client : null;
  String? get userId => _client?.auth.currentUser?.id;
  Stream<String?>? get accountChanges => _client?.auth.onAuthStateChange
      .map((state) => state.session?.user.id)
      .distinct();

  Future<void> publish(
    AppDevice device,
    List<String> addresses,
    String key,
  ) async {
    final owner = userId;
    if (owner == null) throw StateError('Bitte anmelden.');
    await _client!
        .from('account_remote_devices')
        .upsert({
          'owner_user_id': owner,
          'device_id': device.id,
          'name': device.name,
          'platform': device.platform,
          'addresses': addresses,
          'session_key': key,
        }, onConflict: 'owner_user_id,device_id')
        .timeout(const Duration(seconds: 8));
  }

  Future<List<AccountRemoteDevice>> load() async {
    final owner = userId;
    if (owner == null) return [];
    final rows = await _client!
        .from('account_remote_devices')
        .select()
        .eq('owner_user_id', owner)
        .order('name')
        .timeout(const Duration(seconds: 8));
    if (owner != userId) throw StateError('Account wurde gewechselt.');
    return [for (final row in rows) AccountRemoteDevice.fromJson(row)];
  }

  Future<AccountRemoteDevice> find(String id) async {
    final devices = await load();
    return devices.firstWhere((entry) => entry.device.id == id);
  }

  Future<void> revoke(String deviceId) async {
    final owner = userId;
    if (owner == null) return;
    await _client!
        .from('account_remote_devices')
        .delete()
        .eq('owner_user_id', owner)
        .eq('device_id', deviceId)
        .timeout(const Duration(seconds: 8));
  }
}
