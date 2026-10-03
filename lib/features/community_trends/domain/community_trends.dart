import '../../communities/domain/community_statistics.dart';
import '../../statistics/domain/statistics_period.dart';
import '../../statistics/domain/tournament_player_statistics.dart';

enum CommunityTrendKind { rising, practice, stable, insufficient }

class CommunityPlayerTrend {
  const CommunityPlayerTrend(this.player, this.previous, this.recent);
  final CommunityStatisticsPlayer player;
  final TournamentPlayerStatistics? previous, recent;
  static double? rate(TournamentPlayerStatistics? stats) =>
      stats == null || stats.matches == 0
      ? null
      : (stats.wins + stats.draws * .5) * 100 / stats.matches;
  double? get change => rate(previous) == null || rate(recent) == null
      ? null
      : rate(recent)! - rate(previous)!;
  CommunityTrendKind get kind {
    if ((previous?.matches ?? 0) < 5 || (recent?.matches ?? 0) < 5) {
      return CommunityTrendKind.insufficient;
    }
    if (change! >= 15 - 1e-9) return CommunityTrendKind.rising;
    if (change! <= -15 + 1e-9) return CommunityTrendKind.practice;
    return CommunityTrendKind.stable;
  }
}

class CommunityTrends {
  CommunityTrends(CommunityStatistics data, {DateTime? now}) {
    final today = DateUtilsForTrends.day((now ?? DateTime.now()).toLocal());
    final boundary = DateUtilsForTrends.monthsBefore(today, 3);
    recentPeriod = StatisticsPeriod(boundary, today);
    previousPeriod = StatisticsPeriod(
      DateUtilsForTrends.monthsBefore(today, 6),
      DateTime(boundary.year, boundary.month, boundary.day - 1),
    );
    final previous = {
      for (final row in data.rows(period: previousPeriod)) row.id: row,
    };
    final recent = {
      for (final row in data.rows(period: recentPeriod)) row.id: row,
    };
    players =
        [
          for (final player in data.players)
            CommunityPlayerTrend(
              player,
              previous[player.id],
              recent[player.id],
            ),
        ]..sort((a, b) {
          final change = (b.change?.abs() ?? -1).compareTo(
            a.change?.abs() ?? -1,
          );
          return change != 0 ? change : a.player.name.compareTo(b.player.name);
        });
  }
  late final StatisticsPeriod previousPeriod, recentPeriod;
  late final List<CommunityPlayerTrend> players;
}

class DateUtilsForTrends {
  static DateTime day(DateTime value) =>
      DateTime(value.year, value.month, value.day);
  static DateTime monthsBefore(DateTime date, int months) {
    final target = DateTime(date.year, date.month - months);
    final last = DateTime(target.year, target.month + 1, 0).day;
    return DateTime(target.year, target.month, date.day.clamp(1, last));
  }
}
