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
  LocalAccountSessionStore(this._database);

  final LocalAppDatabase _database;

  @override
  String get signInLabel => 'Lokaler Gastmodus';

  @override
  Future<AccountUser?> loadCurrentAccount() => _database.loadCurrentAccount();

  @override
  Future<AccountUser> registerAccount({
    required String displayName,
    required String email,
    required String password,
  }) {
    return _database.registerLocalAccount(
      displayName: displayName,
      email: email,
    );
  }

  @override
  Future<AccountUser?> signInAccount({
    required String email,
    required String password,
  }) {
    return _database.signInLocalAccount(email: email);
  }

  @override
  bool get supportsPasswordReset => false;

  @override
  Future<void> sendPasswordResetEmail({required String email}) {
    throw UnsupportedError('Im lokalen Gastmodus gibt es kein Passwort.');
  }

  @override
  Future<void> signOutCurrentAccount() => _database.signOutCurrentAccount();
}
