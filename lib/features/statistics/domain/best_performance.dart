enum BestPerformanceType { score170, score180, highFinish, shortLeg }

class BestPerformance {
  const BestPerformance({
    required this.type,
    required this.playerName,
    this.playerProfileId,
    this.value,
  });

  final BestPerformanceType type;
  final String playerName;
  final String? playerProfileId;
  final int? value;

  String get label => switch (type) {
    BestPerformanceType.score170 => '170+',
    BestPerformanceType.score180 => '180+',
    BestPerformanceType.highFinish => 'High Finish',
    BestPerformanceType.shortLeg => 'Shortleg',
  };

  factory BestPerformance.fromJson(Map<String, dynamic> json) =>
      BestPerformance(
        type: BestPerformanceType.values.firstWhere(
          (type) => type.name == json['type'],
          orElse: () => BestPerformanceType.score180,
        ),
        playerName: json['playerName'] as String? ?? '',
        playerProfileId: json['playerProfileId'] as String?,
        value: json['value'] as int?,
      );

  Map<String, dynamic> toJson() => {
    'type': type.name,
    'playerName': playerName,
    if (playerProfileId != null) 'playerProfileId': playerProfileId,
    if (value != null) 'value': value,
  };
}
