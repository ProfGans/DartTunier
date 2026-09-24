import 'package:supabase_flutter/supabase_flutter.dart';
import '../../accounts/data/supabase_account_config.dart';
import '../../communities/domain/community_invitation.dart';
import '../domain/app_device.dart';

class CommunityDeviceRepository {
  SupabaseClient get _client {
    if (!SupabaseAccountBootstrap.isInitialized ||
        Supabase.instance.client.auth.currentUser == null) {
      throw StateError('Bitte mit einem Online-Account anmelden.');
    }
    return Supabase.instance.client;
  }

  Future<void> join(AppDevice device, String invitation) async {
    final client = _client;
    final owner = client.auth.currentUser!.id;
    final code = CommunityInvitation.parseInput(invitation);
    if (code == null) throw const FormatException('Ungültige Einladung');
    await client
        .from('account_devices')
        .upsert({
          'owner_user_id': owner,
          'device_id': device.id,
          'name': device.name,
          'platform': device.platform,
          'role': 'match_display',
        }, onConflict: 'owner_user_id,device_id')
        .timeout(const Duration(seconds: 8));
    if (client.auth.currentUser?.id != owner) {
      throw StateError('Account wurde während des Beitritts gewechselt.');
    }
    await client
        .rpc(
          'join_community_as_device',
          params: {'invite_code_input': code, 'device_id_input': device.id},
        )
        .timeout(const Duration(seconds: 8));
  }

  Future<List<Map<String, dynamic>>> groups(String deviceId) async {
    final rows = await _client
        .rpc('my_device_communities', params: {'device_id_input': deviceId})
        .timeout(const Duration(seconds: 8));
    return List<Map<String, dynamic>>.from(rows as List);
  }

  Future<List<Map<String, dynamic>>> devices(String communityId) async =>
      await _client
          .from('community_devices')
          .select()
          .eq('community_id', communityId)
          .order('name')
          .timeout(const Duration(seconds: 8));

  Future<void> leave(String communityId, String deviceId) async {
    final client = _client;
    await client
        .from('community_devices')
        .delete()
        .eq('community_id', communityId)
        .eq('device_id', deviceId)
        .eq('owner_user_id', client.auth.currentUser!.id)
        .timeout(const Duration(seconds: 8));
  }
}
