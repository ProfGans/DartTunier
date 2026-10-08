import '../../../tournaments/domain/tournament_models.dart';
import 'statistics_report.dart';

/// Explicit remote provenance also covers snapshots without communityId.
Map<String, StatisticsReport> communityProfileReports({
  required Iterable<CreatedTournament> tournaments,
  required Map<String, String> tournamentCommunities,
  required Set<String> ownIds,
  Map<String, String> aliases = const {},
  Set<String> communities = const {},
}) {
  final sources = <String, Map<String, CreatedTournament>>{
    for (final id in communities) id: {},
  };
  for (final tournament in tournaments) {
    final id = tournamentCommunities[tournament.id] ?? tournament.communityId;
    if (id == null) continue;
    sources.putIfAbsent(id, () => {})[tournament.id] = tournament;
  }
  return {
    for (final entry in sources.entries)
      entry.key: const StatisticsAnalytics()
          .tournaments(entry.value.values, aliases: aliases)
          .filtered(players: ownIds),
  };
}
