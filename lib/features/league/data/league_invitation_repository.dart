import 'package:supabase_flutter/supabase_flutter.dart';
import '../../accounts/data/supabase_account_config.dart';
import '../../scorer/data/scorer_lobby_repository.dart';
import '../../scorer/domain/scorer_lobby.dart';

class LeagueInvitationRepository {
  LeagueInvitationRepository({SupabaseClient? client}) : _client = client;
  final SupabaseClient? _client;
  SupabaseClient get client => _client ?? Supabase.instance.client;
  String? get userId =>
      (_client != null || SupabaseAccountBootstrap.isInitialized)
      ? client.auth.currentUser?.id
      : null;
  Future<dynamic> call(String action, [Map<String, dynamic> args = const {}]) {
    if (userId == null) throw StateError('Bitte online anmelden.');
    return client
        .rpc(
          'league_invitation_action',
          params: {'action': action, 'args': args},
        )
        .timeout(const Duration(seconds: 12));
  }

  Future<List<ScorerInviteCandidate>> candidates() =>
      ScorerLobbyRepository(client: client).candidates();
  Future<Map<String, dynamic>> invite(
    String match,
    String title,
    int team,
    int slot,
    String user,
  ) async => Map<String, dynamic>.from(
    await call('invite', {
          'match': match,
          'title': title,
          'team': team,
          'slot': slot,
          'user': user,
        })
        as Map,
  );
  Future<List<Map<String, dynamic>>> status(String match) async => [
    for (final row in await call('status', {'match': match}) as List)
      Map<String, dynamic>.from(row as Map),
  ];
  Future<List<Map<String, dynamic>>> inbox() async => [
    for (final row in await call('inbox') as List)
      Map<String, dynamic>.from(row as Map),
  ];
  Future<void> respond(String id, bool accept) async {
    await call('respond', {'id': id, 'accept': accept});
  }

  Future<void> cancel(String id) async {
    await call('cancel', {'id': id});
  }

  Future<void> close(String match) async {
    await call('close', {'match': match});
  }
}
