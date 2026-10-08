import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dart_tournament_manager/features/tournament_invitations/data/tournament_invitation_repository.dart';
import 'package:dart_tournament_manager/features/tournament_invitations/presentation/tournament_invitations_page.dart';
import 'package:dart_tournament_manager/features/tournament_invitations/presentation/tournament_join_page.dart';
import 'package:dart_tournament_manager/features/tournaments/domain/tournament_models.dart';
import 'community_tournament_elo_test.dart' show eloTournament;

class InvitationPreviewRepository extends TournamentInvitationRepository {
  InvitationPreviewRepository():super(client:SupabaseClient('https://example.test','test',authOptions:const AuthClientOptions(autoRefreshToken:false)));
  @override
  Future<String> create(CreatedTournament t) async => '12345678-1234-4234-8234-123456789012';
  @override
  Future<Map<String,dynamic>?> info(String token) async => {'title':'Vereinsmeisterschaft – offenes Doppelturnier'};
  @override
  Future<List<Map<String,dynamic>>> requests(String token) async => [{'id':'test','display_name':'Alexandra mit langem Account-Namen','user_id':'account'}];
  @override
  Future<void> join(String token, String name, String requestId) async {}
}
class TournamentInvitationsPreview extends StatelessWidget {
  const TournamentInvitationsPreview({super.key});
  @override
  Widget build(BuildContext context)=>TournamentInvitationsPage(tournament:eloTournament(),repository:InvitationPreviewRepository(),onAssign:(_,_)async{});
}
class TournamentJoinPreview extends StatelessWidget {
  const TournamentJoinPreview({super.key});
  @override
  Widget build(BuildContext context)=>TournamentJoinPage(token:'test',repository:InvitationPreviewRepository());
}
void main() {
  testWidgets('guest can send registration and gets confirmation', (tester) async {
    await tester.pumpWidget(const MaterialApp(home:TournamentJoinPreview()));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last,'Gast');
    await tester.ensureVisible(find.text('Am Turnier anmelden'));
    await tester.tap(find.text('Am Turnier anmelden'));
    await tester.pumpAndSettle();
    expect(find.text('Anmeldung gesendet. Die Turnierleitung ordnet dich einem Spieler zu.'),findsOneWidget);
  });
  for (final size in [const Size(360,800),const Size(800,600),const Size(1440,900)]) {
    testWidgets('invitation pages and assignment at $size / 200%', (tester) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(()=>tester.binding.setSurfaceSize(null));
      for (final page in [const TournamentJoinPreview(),const TournamentInvitationsPreview()]) {
        await tester.pumpWidget(MaterialApp(builder:(_,child)=>MediaQuery(data:MediaQueryData(size:size,textScaler:TextScaler.linear(2)),child:child!),home:page));
        await tester.pumpAndSettle();
        expect(tester.takeException(),isNull);
      }
      await tester.scrollUntilVisible(find.text('Spieler zuordnen').hitTestable(),150,scrollable:find.byType(Scrollable).first);
      await tester.tap(find.text('Spieler zuordnen').hitTestable());
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog),findsOneWidget);
      expect(tester.takeException(),isNull);
    });
  }
}
