enum WithdrawalResultMode { loseOpen, loseAll, ignoreOpen, ignoreAll }

class PlayerWithdrawal {
  const PlayerWithdrawal({
    required this.playerKey,
    required this.mode,
    required this.createdAt,
    this.countForRanking = false,
    this.countOpponentsForRanking = true,
  });
  final String playerKey;
  final WithdrawalResultMode mode;
  final DateTime createdAt;
  final bool countForRanking, countOpponentsForRanking;
  bool get retroactive =>
      mode == WithdrawalResultMode.loseAll ||
      mode == WithdrawalResultMode.ignoreAll;
  bool get ignore =>
      mode == WithdrawalResultMode.ignoreAll ||
      mode == WithdrawalResultMode.ignoreOpen;
  Map<String, dynamic> toJson() => {
    'version': 1,
    'playerKey': playerKey,
    'mode': mode.name,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'countForRanking': countForRanking,
    'countOpponentsForRanking': countOpponentsForRanking,
  };
  factory PlayerWithdrawal.fromJson(Map<String, dynamic> json) {
    if (json['version'] != 1) {
      throw const FormatException('Unbekannte Ausstiegsversion');
    }
    return PlayerWithdrawal(
      playerKey: json['playerKey'] as String,
      mode: WithdrawalResultMode.values.byName(json['mode'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
      countForRanking: json['countForRanking'] == true,
      countOpponentsForRanking: json['countOpponentsForRanking'] != false,
    );
  }
}
