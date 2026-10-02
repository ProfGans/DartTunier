import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../accounts/data/supabase_account_config.dart';

class PushDevice {
  const PushDevice({
    required this.id,
    required this.name,
    required this.owner,
    required this.platform,
  });
  final String id, name, owner, platform;
}

class AppPushRepository {
  SupabaseClient? get client =>
      SupabaseAccountBootstrap.isInitialized ? Supabase.instance.client : null;
  String? get userId => client?.auth.currentUser?.id;
  Stream<AuthState>? get authChanges => client?.auth.onAuthStateChange;

  Future<bool> canSend() async {
    if (userId == null) return false;
    try {
      return await client!.rpc('can_send_app_push') == true;
    } catch (_) {
      return false;
    }
  }

  Future<List<PushDevice>> devices() async {
    final result = await client!.rpc('list_app_push_devices') as List;
    return result
        .map(
          (row) => PushDevice(
            id: row['id'] as String,
            name: row['name'] as String,
            owner: row['owner'] as String,
            platform: row['platform'] as String,
          ),
        )
        .toList();
  }

  String newRequestId() {
    final random = Random.secure();
    final bytes = List.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 15) | 64;
    bytes[8] = (bytes[8] & 63) | 128;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  Future<Map<String, dynamic>> send({
    required String requestId,
    required String title,
    required String body,
    required List<String> deviceIds,
  }) async {
    final response = await client!.functions.invoke(
      'send-app-push',
      body: {
        'requestId': requestId,
        'title': title.trim(),
        'body': body.trim(),
        'deviceIds': deviceIds,
      },
    );
    return Map<String, dynamic>.from(response.data as Map);
  }
}
