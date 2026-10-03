const defaultCommunityRankingId = 'default';

class CommunityRanking {
  const CommunityRanking({required this.id, required this.name});

  static const standard = CommunityRanking(
    id: defaultCommunityRankingId,
    name: 'Standard-Rangliste',
  );

  final String id;
  final String name;

  factory CommunityRanking.fromJson(Map<String, dynamic> json) =>
      CommunityRanking(id: json['id'] as String, name: json['name'] as String);
}
