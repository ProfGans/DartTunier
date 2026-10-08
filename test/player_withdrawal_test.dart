import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_tournament_manager/features/tournaments/domain/player_withdrawal.dart';
import 'package:dart_tournament_manager/features/tournaments/domain/tournament_models.dart';
import 'package:dart_tournament_manager/features/tournaments/application/player_withdrawal_service.dart';
import 'package:dart_tournament_manager/features/tournaments/application/order_of_play/order_of_play_controller.dart';
import 'package:dart_tournament_manager/features/tournaments/presentation/widgets/run/player_withdrawal_dialog.dart';
import 'package:dart_tournament_manager/features/communities/domain/community_elo.dart';
import 'community_tournament_elo_test.dart' show eloTournament, eloMembers;

void main() {
  for (final mode in WithdrawalResultMode.values) {
    test('withdrawal ${mode.name} persists and applies once', () {
      final t = eloTournament(completed: true);
      final matches = const OrderOfPlayController().entries(t).map((e)=>e.match).toList();
      t.withdrawals.add(PlayerWithdrawal(playerKey: 'a', mode: mode, createdAt: DateTime(2026,10,8)));
      const service = PlayerWithdrawalService();
      service.reconcile(t);
      expect(service.reconcile(t), false);
      if (mode == WithdrawalResultMode.loseAll) {
        expect(matches.first.homeLegs, 0);
      } else {
        expect(matches.first.homeLegs, 3);
      }
      expect(matches.first.withdrawalIgnored, mode == WithdrawalResultMode.ignoreAll);
      final open = matches.last;
      expect(open.isResolved, true);
      expect(open.winner?.profileId, 'b');
      expect(open.countsForStatistics, !t.withdrawals.single.ignore);
      final restored = CreatedTournament.fromJson(t.toJson());
      expect(restored.withdrawals.single.mode, mode);
      expect(service.reconcile(restored), false);
    });
  }
  test('opponent keeps Elo while removed player is excluded from this tournament', () {
    final t = eloTournament(completed: true);
    t.withdrawals.add(PlayerWithdrawal(playerKey:'b', mode:WithdrawalResultMode.ignoreOpen, createdAt:DateTime(2026,10,8)));
    const PlayerWithdrawalService().reconcile(t);
    final result = const CommunityEloCalculator().calculate(members:eloMembers, tournaments:[t], currentYearOnly:false);
    expect(result.entries.map((e)=>e.player.playerProfileId), ['a']);
    expect(result.entries.single.rating, 1016);
  });
  test('ignore-all preserves actual opponent wins but no fake open-game Elo', () {
    final t = eloTournament(completed:true);
    t.withdrawals.add(PlayerWithdrawal(playerKey:'b', mode:WithdrawalResultMode.ignoreAll, createdAt:DateTime(2026,10,8)));
    const PlayerWithdrawalService().reconcile(t);
    final result = const CommunityEloCalculator().calculate(members:eloMembers,tournaments:[t],currentYearOnly:false);
    expect(result.entries.single.matches, 1);
    expect(result.entries.single.rating, 1016);
  });
  for (final size in [const Size(360,800), const Size(800,600), const Size(1440,900)]) {
    testWidgets('withdrawal dialog at $size with large text', (tester) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(()=>tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(MaterialApp(builder:(_, child)=>MediaQuery(data:MediaQueryData(size:size,textScaler:TextScaler.linear(2)), child:child!),
        home:Scaffold(body:PlayerWithdrawalDialog(tournament:eloTournament()))));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
