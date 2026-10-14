import '../../tournaments/data/app_database.dart';
import '../domain/account_user.dart';

abstract class AccountSessionStore {
  String get signInLabel;

  Future<AccountUser?> loadCurrentAccount();

  Future<AccountUser> registerAccount({
    required String displayName,
    required String email,
    required String password,
  });

  Future<AccountUser?> signInAccount({
    required String email,
    required String password,
  });

  bool get supportsPasswordReset;

  Future<void> sendPasswordResetEmail({required String email});

  Future<void> signOutCurrentAccount();
}

class LocalAccountSessionStore implements AccountSessionStore {
  LocalAccountSessionStore([LocalAppDatabase? _]);

  @override
  String get signInLabel => 'Lokaler Gastmodus';

  @override
  Future<AccountUser?> loadCurrentAccount() async => null;

  @override
  Future<AccountUser> registerAccount({
    required String displayName,
    required String email,
    required String password,
  }) => throw UnsupportedError('Lokale App-Konten wurden entfernt.');

  @override
  Future<AccountUser?> signInAccount({
    required String email,
    required String password,
  }) async => null;

  @override
  bool get supportsPasswordReset => false;

  @override
  Future<void> sendPasswordResetEmail({required String email}) {
    throw UnsupportedError('Für Konten wird Supabase benötigt.');
  }

  @override
  Future<void> signOutCurrentAccount() async {}
}
