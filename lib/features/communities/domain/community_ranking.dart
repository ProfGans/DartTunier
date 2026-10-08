const defaultCommunityRankingId = 'default';

class CommunityRanking {
  const CommunityRanking({required this.id, required this.name, this.validityMonths});

  static const standard = CommunityRanking(
    id: defaultCommunityRankingId,
    name: 'Standard-Rangliste',
  );

  final String id;
  final String name;
  final int? validityMonths;

  factory CommunityRanking.fromJson(Map<String, dynamic> json) =>
      CommunityRanking(id: json['id'] as String, name: json['name'] as String,
        validityMonths: json['validity_months'] as int?);
}

/// Calendar months, clamped to the last day of the target month.
DateTime rankingCutoff(DateTime now, int months) {
  final first = DateTime(now.year, now.month - months);
  final lastDay = DateTime(first.year, first.month + 1, 0).day;
  return DateTime(first.year, first.month, now.day > lastDay ? lastDay : now.day);
}
