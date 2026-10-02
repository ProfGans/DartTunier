import 'package:supabase_flutter/supabase_flutter.dart';
import '../../accounts/data/supabase_account_config.dart';
import '../domain/scorer_lobby.dart';

class ScorerLobbyRepository {
  ScorerLobbyRepository({SupabaseClient? client}) : _client = client;
  final SupabaseClient? _client;
  SupabaseClient get client => _client ?? Supabase.instance.client;
  bool get signedIn =>
      (_client != null || SupabaseAccountBootstrap.isInitialized) &&
      client.auth.currentUser != null;
  String? get userId => signedIn ? client.auth.currentUser!.id : null;
  Future<dynamic> _call(
    String action, [
    Map<String, dynamic> args = const {},
  ]) async {
    if (!signedIn) throw StateError('Bitte mit einem Online-Konto anmelden.');
    return client
        .rpc('scorer_lobby_action', params: {'action': action, 'args': args})
        .timeout(const Duration(seconds: 12));
  }

  Future<ScorerLobby> create() async => ScorerLobby.fromJson(
    Map<String, dynamic>.from(await _call('create') as Map),
  );
  Future<ScorerLobby> snapshot(String id) async => ScorerLobby.fromJson(
    Map<String, dynamic>.from(await _call('snapshot', {'id': id}) as Map),
  );
  Future<ScorerLobby> close(String id) async => ScorerLobby.fromJson(
    Map<String, dynamic>.from(await _call('close', {'id': id}) as Map),
  );
  Future<void> remove(String id, String member) async =>
      _call('remove', {'id': id, 'user_id': member});
  Future<void> join(String code) async => _call('join', {'code': code});
  Future<void> invite(String id, String user) async =>
      _call('invite', {'id': id, 'user_id': user});
  Future<void> respond(String invitation, bool accept) async =>
      _call('respond', {'invitation': invitation, 'accept': accept});
  Future<List<ScorerInvitation>> invitations() async => [
    for (final row in await _call('invitations') as List)
      ScorerInvitation.fromJson(Map<String, dynamic>.from(row as Map)),
  ];
  Future<List<ScorerInviteCandidate>> candidates() async => [
    for (final row in await _call('candidates') as List)
      ScorerInviteCandidate.fromJson(Map<String, dynamic>.from(row as Map)),
  ];
}
