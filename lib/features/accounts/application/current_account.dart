import '../data/supabase_account_config.dart';
import '../data/supabase_account_session_store.dart';
import '../domain/account_user.dart';
import '../../tournaments/data/app_database.dart';

Future<AccountUser?> loadCurrentAccount() =>
    SupabaseAccountBootstrap.isInitialized
    ? SupabaseAccountSessionStore().loadCurrentAccount()
    : LocalAppDatabase().loadCurrentAccount();
