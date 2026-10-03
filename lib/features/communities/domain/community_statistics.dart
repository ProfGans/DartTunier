import '../../statistics/domain/statistics_period.dart';
import '../../statistics/domain/tournament_player_statistics.dart';
import '../../tournaments/domain/tournament_models.dart';
import 'community.dart';
import 'community_member_identity.dart';

class CommunityStatisticsPlayer {
  const CommunityStatisticsPlayer(this.id, this.name);
  final String id, name;
}

/// A community-scoped snapshot, including members who have not played yet.
class CommunityStatistics {
  CommunityStatistics({
    required this.communityId,
    required List<CommunityMember> members,
    required List<CreatedTournament> tournaments,
  }) : members = effectiveCommunityMembers(members),
       tournaments = {
         for (final t in tournaments)
           if (t.communityId == communityId) t.id: t,
       }.values.toList();
  final List<CommunityMember> members;
  final String communityId;
  final List<CreatedTournament> tournaments;

  Map<String, String> get aliases => {
    for (final member in members)
      for (final alias in member.aliasProfileIds)
        alias: member.playerProfileId ?? member.displayName,
  };

  List<TournamentPlayerStatistics> rows({
    StatisticsPeriod? period,
    Iterable<CreatedTournament>? source,
  }) => const TournamentStatisticsCalculator().calculate(
    source ?? tournaments,
    aliases: aliases,
    period: period,
  );

  List<CommunityStatisticsPlayer> get players {
    final all = {
      for (final row in rows())
        row.id: CommunityStatisticsPlayer(row.id, row.name),
    };
    for (final member in members) {
      final id =
          member.playerProfileId ??
          'member:${member.userId ?? member.displayName}';
      all[id] = CommunityStatisticsPlayer(id, member.displayName);
    }
    return all.values.toList()..sort((a, b) {
      final name = a.name.toLowerCase().compareTo(b.name.toLowerCase());
      return name == 0 ? a.id.compareTo(b.id) : name;
    });
  }
}
