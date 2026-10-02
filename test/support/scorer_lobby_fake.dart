import 'package:dart_tournament_manager/features/scorer/data/scorer_lobby_repository.dart';
import 'package:dart_tournament_manager/features/scorer/domain/scorer_lobby.dart';

class FakeScorerLobbyRepository extends ScorerLobbyRepository {
  String? currentUser = 'host';
  List<LobbyMember> members = [];
  List<ScorerInvitation> pending = [];
  bool open = true, failClose = false;
  int joins = 0, closes = 0;
  String? invited;
  bool? accepted;
  @override
  bool get signedIn => currentUser != null;
  @override
  String? get userId => currentUser;
  ScorerLobby snapshotValue() => ScorerLobby.fromJson({
    'id': 'room',
    'code': '0123456789ABCDEF0123456789ABCDEF',
    'open': open,
    'expires_at': DateTime.now()
        .add(const Duration(hours: 2))
        .toIso8601String(),
    'members': [
      for (final m in members) {'user_id': m.id, 'display_name': m.name},
    ],
  });
  @override
  Future<ScorerLobby> create() async => snapshotValue();
  @override
  Future<ScorerLobby> snapshot(String id) async => snapshotValue();
  @override
  Future<ScorerLobby> close(String id) async {
    if (failClose) throw StateError('Offline');
    closes++;
    open = false;
    return snapshotValue();
  }

  @override
  Future<void> remove(String id, String member) async {
    members.removeWhere((m) => m.id == member);
  }

  @override
  Future<void> join(String code) async {
    joins++;
  }

  @override
  Future<void> invite(String id, String user) async {
    invited = user;
  }

  @override
  Future<List<ScorerInviteCandidate>> candidates() async => [
    const ScorerInviteCandidate('guest', 'Anna Beispiel', 'Dartfreunde'),
  ];
  @override
  Future<List<ScorerInvitation>> invitations() async => pending;
  @override
  Future<void> respond(String invitation, bool accept) async {
    accepted = accept;
    pending = [];
  }
}
