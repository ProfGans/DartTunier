import 'package:supabase_flutter/supabase_flutter.dart';

import '../application/account_session_store.dart';
import '../domain/account_user.dart';

class SupabaseAccountSessionStore implements AccountSessionStore {
  SupabaseAccountSessionStore({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  @override
  String get signInLabel => 'Supabase Online-Account';

  @override
  Future<AccountUser?> loadCurrentAccount() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      return null;
    }
    return _accountFromSupabaseUser(user);
  }

  @override
  Future<AccountUser> registerAccount({
    required String displayName,
    required String email,
    required String password,
  }) async {
    final response = await _client.auth.signUp(
      email: email.trim(),
      password: password,
      data: {
        'display_name': displayName.trim(),
      },
    );
    final user = response.user;
    if (user == null) {
      throw const AuthException(
        'Account wurde angelegt. Bitte bestaetige deine E-Mail und melde dich danach an.',
      );
    }
    if (response.session == null) {
      throw const AuthException(
        'Account wurde angelegt. Bitte bestaetige deine E-Mail und melde dich danach an.',
      );
    }

    await _upsertPlayerProfile(
      userId: user.id,
      displayName: displayName,
    );
    return _accountFromSupabaseUser(user);
  }

  @override
  Future<AccountUser?> signInAccount({
    required String email,
    required String password,
  }) async {
    final response = await _client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
    final user = response.user;
    if (user == null) {
      return null;
    }

    final metadata = user.userMetadata ?? const <String, dynamic>{};
    await _upsertPlayerProfile(
      userId: user.id,
      displayName:
          (metadata['display_name'] as String?) ?? user.email ?? 'Spieler',
    );
    return _accountFromSupabaseUser(user);
  }

  @override
  Future<void> signOutCurrentAccount() => _client.auth.signOut();

  Future<void> _upsertPlayerProfile({
    required String userId,
    required String displayName,
  }) async {
    await _client.from('player_profiles').upsert({
      'id': userId,
      'user_id': userId,
      'display_name': displayName.trim(),
      'is_active': true,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  AccountUser _accountFromSupabaseUser(User user) {
    final metadata = user.userMetadata ?? const <String, dynamic>{};
    final displayName =
        (metadata['display_name'] as String?) ?? user.email ?? 'Spieler';
    final createdAt = DateTime.tryParse(user.createdAt) ??
        DateTime.fromMillisecondsSinceEpoch(0);
    final lastLogin = user.lastSignInAt == null
        ? null
        : DateTime.tryParse(user.lastSignInAt!);

    return AccountUser(
      id: user.id,
      username: user.email?.split('@').first ?? user.id,
      displayName: displayName,
      email: user.email ?? '',
      avatarUrl: (metadata['avatar_url'] as String?),
      createdAt: createdAt,
      updatedAt: lastLogin ?? createdAt,
      lastLogin: lastLogin,
      isActive: true,
    );
  }
}
