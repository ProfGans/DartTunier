import 'community_elo.dart';

class CommunityEloRecords {
  CommunityEloRecords(List<CommunityEloHistoryItem> history) {
    for (final item in history) {
      if (item.ratingAfter > peak) peak = item.ratingAfter;
      if (item.delta > largestGain) largestGain = item.delta;
    }
  }
  int peak = communityInitialElo;
  int largestGain = 0;
}
