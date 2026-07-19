import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseAccountConfig {
  const SupabaseAccountConfig._();

  static const url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://hnsyvqtqxdsbbyrayobv.supabase.co',
  );
  static const publishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: 'sb_publishable_ED8NE9CWSRclj6lQ2baNqw_JPrpXsQB',
  );
  static const anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: publishableKey,
  );

  static bool get isConfigured => url.isNotEmpty && anonKey.isNotEmpty;
}

class SupabaseAccountBootstrap {
  const SupabaseAccountBootstrap._();

  static Future<void> initialize() async {
    WidgetsFlutterBinding.ensureInitialized();
    if (!SupabaseAccountConfig.isConfigured) {
      return;
    }

    await Supabase.initialize(
      url: SupabaseAccountConfig.url,
      publishableKey: SupabaseAccountConfig.anonKey,
    );
  }
}
