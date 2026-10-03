enum RankingPlayerAction { remove, reset }

/// Append-only administration history; cached JSON schema v1.
class CommunityRankingAction {
  const CommunityRankingAction({
    required this.id,
    required this.rankingId,
    required this.playerKey,
    required this.action,
    required this.createdAt,
  });
  final int id;
  final String rankingId, playerKey;
  final RankingPlayerAction action;
  final DateTime createdAt;

  factory CommunityRankingAction.fromJson(Map<String, dynamic> json) =>
      CommunityRankingAction(
        id: (json['id'] as num).toInt(),
        rankingId: json['ranking_id'] as String,
        playerKey: json['player_key'] as String,
        action: RankingPlayerAction.values.byName(json['action'] as String),
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}
