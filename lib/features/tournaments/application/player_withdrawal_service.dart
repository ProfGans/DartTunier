import '../domain/player_withdrawal.dart';
import '../domain/tournament_models.dart';
import 'order_of_play/order_of_play_controller.dart';

class PlayerWithdrawalService {
  const PlayerWithdrawalService();
  static String key(TournamentPlayer p) => p.profileId ?? p.name;
  static PlayerWithdrawal? policy(CreatedTournament t, TournamentPlayer p) =>
      t.withdrawals.where((w) => w.playerKey == key(p)).firstOrNull;

  /// Idempotent: generated later-round matches receive the same durable rule.
  bool reconcile(CreatedTournament t) {
    var changed = false;
    for (final entry in const OrderOfPlayController().entries(t)) {
      final m = entry.match;
      if (!m.hasPlayers) continue;
      final home = policy(t, m.homePlayer!);
      final away = policy(t, m.awayPlayer!);
      final signature = '${key(m.homePlayer!)}|${key(m.awayPlayer!)}|${home?.createdAt.toUtc().toIso8601String()}|${away?.createdAt.toUtc().toIso8601String()}';
      if (m.withdrawalSignature != null && m.withdrawalSignature != signature) {
        if (!m.withdrawalHadResult) {
          m.homeLegs = null; m.awayLegs = null;
          m.homeSets = null; m.awaySets = null;
          m.isAnnulled = false;
        }
        m.withdrawalSignature = null;
        m.withdrawalIgnored = false;
        m.withdrawalHadResult = false;
      }
      if (home == null && away == null) continue;
      if (m.withdrawalSignature == signature) continue;
      final rules = [?home, ?away];
      if (m.hasResult && !rules.any((r) => r.retroactive)) continue;
      final ignore = rules.any((r) => r.ignore);
      final wasPlayed = m.hasResult;
      m.withdrawalSignature = signature;
      m.withdrawalIgnored = ignore;
      m.withdrawalHadResult = wasPlayed;
      // Keep actual past results for optional opponent Elo, but exclude them
      // from the tournament table when the director selected ignore-all.
      if (!(ignore && wasPlayed)) {
        final format = t.stages[entry.stageIndex].gameFormat;
        final legs = format.bestOfLegs ~/ 2 + 1;
        final sets = format.bestOfSets ~/ 2 + 1;
        final homeWins = home == null;
        m.homeLegs = homeWins ? legs * (format.bestOfSets > 1 ? sets : 1) : 0;
        m.awayLegs = away == null
            ? legs * (format.bestOfSets > 1 ? sets : 1)
            : 0;
        m.homeSets = format.bestOfSets > 1 ? (homeWins ? sets : 0) : null;
        m.awaySets = format.bestOfSets > 1 ? (away == null ? sets : 0) : null;
        m.deviceResult = null;
        m.isAnnulled = home != null && away != null;
        m.finishedAt = rules
            .map((r) => r.createdAt)
            .reduce((a, b) => a.isAfter(b) ? a : b);
      }
      m.boardNumber = null;
      m.startedAt = null;
      m.startedPlayers = null;
      changed = true;
    }
    return changed;
  }
}
