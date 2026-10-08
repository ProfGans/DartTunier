import 'package:flutter_test/flutter_test.dart';
import 'package:dart_tournament_manager/features/tournament_invitations/domain/tournament_invitation.dart';
import 'package:dart_tournament_manager/features/tournament_invitations/domain/invitation_request_id.dart';
import 'package:dart_tournament_manager/features/tournament_invitations/application/assign_tournament_registration.dart';
import 'package:dart_tournament_manager/features/tournaments/application/order_of_play/order_of_play_controller.dart';
import 'community_tournament_elo_test.dart' show eloTournament, eloPlayers;

void main() {
  test('HTTPS and native tournament links round trip, unrelated URLs rejected', () {
    final token = invitationRequestId();
    expect(TournamentInvitation.parse(Uri.parse(TournamentInvitation.link(token))),token);
    expect(TournamentInvitation.parse(Uri.parse('dartturnier://tournament/join?token=$token')),token);
    for (final link in ['https://evil.test/?tournament=$token','dartturnier://tournament/join?token=bad',
      '${TournamentInvitation.link(token)}&tournament=$token','${TournamentInvitation.link(token)}#other']) {
      expect(TournamentInvitation.parse(Uri.parse(link)),isNull);
    }
  });
  test('new registration expands initial roster without changing source', () {
    final t=eloTournament();
    final result=assignTournamentRegistration(t,{'id':invitationRequestId(),'display_name':'Gast'},null);
    expect(result.players.length,3);
    expect(t.players.length,2);
  });
  test('running tournament blocks roster expansion and foreign account takeover', () {
    final t=eloTournament(completed:true);
    final r={'id':invitationRequestId(),'user_id':'other','display_name':'Gast'};
    expect(()=>assignTournamentRegistration(t,r,null),throwsStateError);
    expect(()=>assignTournamentRegistration(t,r,eloPlayers.first),throwsStateError);
  });
  test('matching account assignment retains results', () {
    final t=eloTournament(completed:true);
    final next=assignTournamentRegistration(t,{'id':invitationRequestId(),'user_id':'a','display_name':'A'},eloPlayers.first);
    expect(const OrderOfPlayController().entries(next).first.match.homeLegs,3);
    expect(next.players.first.name,'A');
    expect(const OrderOfPlayController().entries(next).first.match.homePlayer!.name,'A');
  });
}
