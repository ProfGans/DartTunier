import 'package:supabase_flutter/supabase_flutter.dart';
import '../../accounts/data/supabase_account_config.dart';
import '../domain/app_device.dart';

class DeviceAccountRepository {
  SupabaseClient? get _client =>
      SupabaseAccountBootstrap.isInitialized ? Supabase.instance.client : null;
  String? get userId => _client?.auth.currentUser?.id;
  Stream<AuthState>? get authChanges => _client?.auth.onAuthStateChange;
  Future<List<AppDevice>> load() async {
    final owner = userId;
    if (owner == null) return [];
    final rows = await _client!
        .from('account_devices')
        .select('device_id, name, platform')
        .eq('owner_user_id', owner)
        .order('name')
        .timeout(const Duration(seconds: 8));
    return [
      for (final row in rows)
        AppDevice.fromJson({
          'id': row['device_id'],
          'name': row['name'],
          'platform': row['platform'],
        }),
    ];
  }

  Future<void> register(AppDevice device) async {
    final owner = userId;
    if (owner == null) {
      throw StateError('Bitte mit einem Online-Account anmelden.');
    }
    await _client!
        .from('account_devices')
        .upsert({
          'owner_user_id': owner,
          'device_id': device.id,
          'name': device.name,
          'platform': device.platform,
          'role': 'match_display',
        }, onConflict: 'owner_user_id,device_id')
        .timeout(const Duration(seconds: 8));
  }

  Future<void> remove(String id) async {
    final owner = userId;
    if (owner == null) throw StateError('Bitte anmelden.');
    await _client!
        .from('account_devices')
        .delete()
        .eq('owner_user_id', owner)
        .eq('device_id', id)
        .timeout(const Duration(seconds: 8));
  }
}
