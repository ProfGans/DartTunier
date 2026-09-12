import 'dart:math';

const List<String> defaultGroupTieBreakers = [
  'points',
  'legDifference',
  'legsFor',
  'headToHead',
];

String groupLabel(int groupNumber) {
  var number = groupNumber;
  var label = '';
  while (number > 0) {
    number--;
    label = String.fromCharCode(65 + (number % 26)) + label;
    number ~/= 26;
  }

  return 'Gruppe $label';
}

String tieBreakerLabel(String tieBreaker) {
  return switch (tieBreaker) {
    'points' => 'Punkte',
    'legDifference' => 'Leg-Differenz',
    'legsFor' => 'Gewonnene Legs',
    'headToHead' => 'Direkter Vergleich',
    _ => tieBreaker,
  };
}

String _newTournamentId() {
  final timestamp = DateTime.now().microsecondsSinceEpoch;
  final randomPart = Random().nextInt(1 << 32);
  return '$timestamp-$randomPart';
}

DateTime? _dateTimeFromJson(Object? value) {
  if (value is! String) {
    return null;
  }
  return DateTime.tryParse(value);
}

List<int> _intListFromJson(Object? value) {
  if (value is! List) {
    return const [];
  }
  return [for (final item in value) if (item is int) item];
}

List<int?> _nullableIntListFromJson(Object? value) {
  if (value is! List) {
    return const [];
  }
  return [for (final item in value) item is int ? item : null];
}

List<String> _stringListFromJson(
  Object? value, {
  List<String> fallback = const [],
}) {
  if (value is! List) {
    return List<String>.from(fallback);
  }
  return [for (final item in value) if (item is String) item];
}

List<T> _mapListFromJson<T>(
  Object? value,
  T Function(Map<String, dynamic> json) fromJson,
) {
  if (value is! List) {
    return [];
  }
  return [
    for (final item in value)
      if (item is Map<String, dynamic>) fromJson(item),
  ];
}

TournamentPlayer? _playerFromJson(Object? value) {
  if (value is! Map<String, dynamic>) {
    return null;
  }
  return TournamentPlayer.fromJson(value);
}

List<List<GroupMatch>> _matchRoundsFromJson(Object? value) {
  if (value is! List) {
    return [];
  }
  return [
    for (final round in value)
      if (round is List)
        [
          for (final match in round)
            if (match is Map<String, dynamic>) GroupMatch.fromJson(match),
        ],
  ];
}

List<TournamentRunStage> _runStageListFromJson(Object? value) {
  if (value is! List) {
    return [];
  }

  return [
    for (final item in value)
      if (item is Map<String, dynamic>) _runStageFromJson(item),
  ];
}

TournamentRunStage _runStageFromJson(Map<String, dynamic> json) {
  final kind = json['kind'] as String?;
  if (kind == 'single_knockout') {
    return KnockoutTournamentRunStage(
      name: json['name'] as String? ?? '',
      rounds: _matchRoundsFromJson(json['rounds']),
      placementMatches: _mapListFromJson(
        json['placementMatches'],
        GroupMatch.fromJson,
      ),
      eliminationLossLimit: json['eliminationLossLimit'] as int? ?? 1,
    );
  }

  return GroupTournamentRunStage(
    name: json['name'] as String? ?? '',
    groupPlayType: json['groupPlayType'] as String? ?? 'round_robin',
    groups: _mapListFromJson(json['groups'], TournamentGroup.fromJson),
    qualificationPlan: json['qualificationPlan'] is Map<String, dynamic>
        ? QualificationPlan.fromJson(
            json['qualificationPlan'] as Map<String, dynamic>,
          )
        : null,
    tieBreakers: _stringListFromJson(
      json['tieBreakers'],
      fallback: defaultGroupTieBreakers,
    ),
  );
}

Map<String, dynamic> _runStageToJson(TournamentRunStage stage) {
  if (stage is GroupTournamentRunStage) {
    return stage.toJson();
  }
  if (stage is KnockoutTournamentRunStage) {
    return stage.toJson();
  }
  return {'kind': 'unknown', 'name': stage.name};
}

class TournamentPlayer {
  const TournamentPlayer({
    this.profileId,
    required this.name,
    required this.isGenerated,
  });

  factory TournamentPlayer.fromJson(Map<String, dynamic> json) {
    return TournamentPlayer(
      profileId: json['profileId'] as String?,
      name: json['name'] as String? ?? '',
      isGenerated: json['isGenerated'] as bool? ?? false,
    );
  }

  factory TournamentPlayer.generated(int number) {
    return TournamentPlayer(name: 'Spieler $number', isGenerated: true);
  }

  final String? profileId;
  final String name;
  final bool isGenerated;

  TournamentPlayer copyWith({
    String? profileId,
    String? name,
    bool? isGenerated,
  }) {
    return TournamentPlayer(
      profileId: profileId ?? this.profileId,
      name: name ?? this.name,
      isGenerated: isGenerated ?? this.isGenerated,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (profileId != null) 'profileId': profileId,
      'name': name,
      'isGenerated': isGenerated,
    };
  }

  @override
  bool operator ==(Object other) {
    return other is TournamentPlayer &&
        other.profileId == profileId &&
        other.name == name &&
        other.isGenerated == isGenerated;
  }

  @override
  int get hashCode => Object.hash(profileId, name, isGenerated);
}

class TournamentStage {
  const TournamentStage({
    required this.name,
    required this.type,
    this.groupCount,
    this.groupSizes = const [],
    this.groupPlayType = 'round_robin',
    this.groupPlayTypes = const [],
    this.groupRoundRobinRepeats = const [],
    this.groupTieBreakers = defaultGroupTieBreakers,
    this.groupDrawOnStart = false,
    this.groupSlotOrder = const [],
    this.knockoutParticipantCount,
    this.knockoutBracketSize,
    this.knockoutByeCount = 0,
    this.knockoutSlotOrder = const [],
    this.knockoutSeedingMode = 'cross',
    this.knockoutDrawOnStart = false,
    this.qualifiersByGroup = const [],
    this.fixedQualifiersByGroup = const [],
    this.extraQualifierRank,
    this.extraQualifierCount,
    this.qualificationAutoAdjust = true,
    this.qualifiedParticipantCount,
    this.qualificationSummary,
    this.gameFormat = const TournamentGameFormat(),
  });

  factory TournamentStage.fromJson(Map<String, dynamic> json) {
    return TournamentStage(
      name: json['name'] as String? ?? '',
      type: json['type'] as String? ?? 'groups',
      groupCount: json['groupCount'] as int?,
      groupSizes: _intListFromJson(json['groupSizes']),
      groupPlayType: json['groupPlayType'] as String? ?? 'round_robin',
      groupPlayTypes: _stringListFromJson(json['groupPlayTypes']),
      groupRoundRobinRepeats: _intListFromJson(
        json['groupRoundRobinRepeats'],
      ),
      groupTieBreakers: _stringListFromJson(
        json['groupTieBreakers'],
        fallback: defaultGroupTieBreakers,
      ),
      groupDrawOnStart: json['groupDrawOnStart'] as bool? ?? false,
      groupSlotOrder: _nullableIntListFromJson(json['groupSlotOrder']),
      knockoutParticipantCount: json['knockoutParticipantCount'] as int?,
      knockoutBracketSize: json['knockoutBracketSize'] as int?,
      knockoutByeCount: json['knockoutByeCount'] as int? ?? 0,
      knockoutSlotOrder: _nullableIntListFromJson(json['knockoutSlotOrder']),
      knockoutSeedingMode: json['knockoutSeedingMode'] as String? ?? 'cross',
      knockoutDrawOnStart: json['knockoutDrawOnStart'] as bool? ?? false,
      qualifiersByGroup: _intListFromJson(json['qualifiersByGroup']),
      fixedQualifiersByGroup: _intListFromJson(
        json['fixedQualifiersByGroup'],
      ),
      extraQualifierRank: json['extraQualifierRank'] as int?,
      extraQualifierCount: json['extraQualifierCount'] as int?,
      qualificationAutoAdjust: json['qualificationAutoAdjust'] as bool? ?? true,
      qualifiedParticipantCount: json['qualifiedParticipantCount'] as int?,
      qualificationSummary: json['qualificationSummary'] as String?,
      gameFormat: json['gameFormat'] is Map<String, dynamic>
          ? TournamentGameFormat.fromJson(json['gameFormat'] as Map<String, dynamic>)
          : const TournamentGameFormat(),
    );
  }

  final String name;
  final String type;
  final int? groupCount;
  final List<int> groupSizes;
  final String groupPlayType;
  final List<String> groupPlayTypes;
  final List<int> groupRoundRobinRepeats;
  final List<String> groupTieBreakers;
  final bool groupDrawOnStart;
  final List<int?> groupSlotOrder;
  final int? knockoutParticipantCount;
  final int? knockoutBracketSize;
  final int knockoutByeCount;
  final List<int?> knockoutSlotOrder;
  final String knockoutSeedingMode;
  final bool knockoutDrawOnStart;
  final List<int> qualifiersByGroup;
  final List<int> fixedQualifiersByGroup;
  final int? extraQualifierRank;
  final int? extraQualifierCount;
  final bool qualificationAutoAdjust;
  final int? qualifiedParticipantCount;
  final String? qualificationSummary;
  final TournamentGameFormat gameFormat;

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'type': type,
      'groupCount': groupCount,
      'groupSizes': groupSizes,
      'groupPlayType': groupPlayType,
      'groupPlayTypes': groupPlayTypes,
      'groupRoundRobinRepeats': groupRoundRobinRepeats,
      'groupTieBreakers': groupTieBreakers,
      'groupDrawOnStart': groupDrawOnStart,
      'groupSlotOrder': groupSlotOrder,
      'knockoutParticipantCount': knockoutParticipantCount,
      'knockoutBracketSize': knockoutBracketSize,
      'knockoutByeCount': knockoutByeCount,
      'knockoutSlotOrder': knockoutSlotOrder,
      'knockoutSeedingMode': knockoutSeedingMode,
      'knockoutDrawOnStart': knockoutDrawOnStart,
      'qualifiersByGroup': qualifiersByGroup,
      'fixedQualifiersByGroup': fixedQualifiersByGroup,
      'extraQualifierRank': extraQualifierRank,
      'extraQualifierCount': extraQualifierCount,
      'qualificationAutoAdjust': qualificationAutoAdjust,
      'qualifiedParticipantCount': qualifiedParticipantCount,
      'qualificationSummary': qualificationSummary,
      'gameFormat': gameFormat.toJson(),
    };
  }
}

/// Das tatsächlich gespielte Format einer Etappe. Es ist bewusst unabhängig
/// von der Planungs-Schätzung gespeichert, damit es später in der Übersicht
/// und bei Ergebnissen zuverlässig angezeigt werden kann.
class TournamentGameFormat {
  const TournamentGameFormat({
    this.gameType = 'x01',
    this.x01Score = 501,
    this.checkoutType = 'double_out',
    this.doubleIn = false,
    this.bestOfLegs = 3,
  });

  factory TournamentGameFormat.fromJson(Map<String, dynamic> json) {
    return TournamentGameFormat(
      gameType: json['gameType'] as String? ?? 'x01',
      x01Score: json['x01Score'] as int? ?? 501,
      checkoutType: json['checkoutType'] as String? ?? 'double_out',
      doubleIn: json['doubleIn'] as bool? ?? false,
      bestOfLegs: json['bestOfLegs'] as int? ?? 3,
    );
  }

  final String gameType;
  final int x01Score;
  final String checkoutType;
  final bool doubleIn;
  final int bestOfLegs;

  String get checkoutLabel => switch (checkoutType) {
    'single_out' => 'Single Out',
    'master_out' => 'Master Out',
    _ => 'Double Out',
  };

  String get label => gameType == 'cricket'
      ? 'Cricket · Best of $bestOfLegs Legs'
      : '$x01Score ${doubleIn ? 'Double In / ' : ''}$checkoutLabel · Best of $bestOfLegs Legs';

  Map<String, dynamic> toJson() => {
    'gameType': gameType,
    'x01Score': x01Score,
    'checkoutType': checkoutType,
    'doubleIn': doubleIn,
    'bestOfLegs': bestOfLegs,
  };
}

class CreatedTournament {
  CreatedTournament({
    String? id,
    DateTime? createdAt,
    DateTime? updatedAt,
    required this.name,
    required this.players,
    required this.stages,
    required this.runStages,
    this.communityId,
    this.activeStageIndex = 0,
    Set<int>? completedStageIndexes,
  }) : id = id ?? _newTournamentId(),
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now(),
       completedStageIndexes = completedStageIndexes ?? <int>{};

  factory CreatedTournament.fromJson(Map<String, dynamic> json) {
    return CreatedTournament(
      id: json['id'] as String?,
      createdAt: _dateTimeFromJson(json['createdAt']),
      updatedAt: _dateTimeFromJson(json['updatedAt']),
      name: json['name'] as String? ?? 'Neues Turnier',
      players: _mapListFromJson(
        json['players'],
        TournamentPlayer.fromJson,
      ),
      stages: _mapListFromJson(json['stages'], TournamentStage.fromJson),
      runStages: _runStageListFromJson(json['runStages']),
      communityId: json['communityId'] as String?,
      activeStageIndex: json['activeStageIndex'] as int? ?? 0,
      completedStageIndexes: _intListFromJson(
        json['completedStageIndexes'],
      ).toSet(),
    );
  }

  final String id;
  final String name;
  final DateTime createdAt;
  DateTime updatedAt;
  final List<TournamentPlayer> players;
  final List<TournamentStage> stages;
  final List<TournamentRunStage> runStages;
  final String? communityId;
  int activeStageIndex;
  final Set<int> completedStageIndexes;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'players': players.map((player) => player.toJson()).toList(),
      'stages': stages.map((stage) => stage.toJson()).toList(),
      'runStages': runStages.map(_runStageToJson).toList(),
      'communityId': communityId,
      'activeStageIndex': activeStageIndex,
      'completedStageIndexes': completedStageIndexes.toList()..sort(),
    };
  }
}

abstract class TournamentRunStage {
  const TournamentRunStage({required this.name});

  final String name;
}

class GroupTournamentRunStage extends TournamentRunStage {
  const GroupTournamentRunStage({
    required super.name,
    required this.groupPlayType,
    required this.groups,
    required this.qualificationPlan,
    required this.tieBreakers,
  });

  final String groupPlayType;
  final List<TournamentGroup> groups;
  final QualificationPlan? qualificationPlan;
  final List<String> tieBreakers;

  Map<String, dynamic> toJson() {
    return {
      'kind': 'groups',
      'name': name,
      'groupPlayType': groupPlayType,
      'groups': groups.map((group) => group.toJson()).toList(),
      'qualificationPlan': qualificationPlan?.toJson(),
      'tieBreakers': tieBreakers,
    };
  }
}

class KnockoutTournamentRunStage extends TournamentRunStage {
  const KnockoutTournamentRunStage({
    required super.name,
    required this.rounds,
    this.placementMatches = const [],
    this.eliminationLossLimit = 1,
  });

  final List<List<GroupMatch>> rounds;
  final List<GroupMatch> placementMatches;
  final int eliminationLossLimit;

  List<GroupMatch> get matches => [
    for (final round in rounds) ...round,
    ...placementMatches,
  ];

  Map<String, dynamic> toJson() {
    return {
      'kind': 'single_knockout',
      'name': name,
      'rounds': rounds
          .map((round) => round.map((match) => match.toJson()).toList())
          .toList(),
      'placementMatches': placementMatches
          .map((match) => match.toJson())
          .toList(),
      'eliminationLossLimit': eliminationLossLimit,
    };
  }
}

class TournamentGroup {
  TournamentGroup({
    required this.name,
    required this.playType,
    required this.players,
    required this.matches,
    this.knockoutRounds = const [],
    this.placementMatches = const [],
    this.eliminationLossLimit = 1,
  });

  final String name;
  final String playType;
  final List<TournamentPlayer> players;
  final List<GroupMatch> matches;
  final List<List<GroupMatch>> knockoutRounds;
  final List<GroupMatch> placementMatches;
  final int eliminationLossLimit;

  factory TournamentGroup.fromJson(Map<String, dynamic> json) {
    return TournamentGroup(
      name: json['name'] as String? ?? '',
      playType: json['playType'] as String? ?? 'round_robin',
      players: _mapListFromJson(json['players'], TournamentPlayer.fromJson),
      matches: _mapListFromJson(json['matches'], GroupMatch.fromJson),
      knockoutRounds: _matchRoundsFromJson(json['knockoutRounds']),
      placementMatches: _mapListFromJson(
        json['placementMatches'],
        GroupMatch.fromJson,
      ),
      eliminationLossLimit: json['eliminationLossLimit'] as int? ?? 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'playType': playType,
      'players': players.map((player) => player.toJson()).toList(),
      'matches': matches.map((match) => match.toJson()).toList(),
      'knockoutRounds': knockoutRounds
          .map((round) => round.map((match) => match.toJson()).toList())
          .toList(),
      'placementMatches': placementMatches
          .map((match) => match.toJson())
          .toList(),
      'eliminationLossLimit': eliminationLossLimit,
    };
  }
}

class GroupMatch {
  GroupMatch({
    this.homePlayer,
    this.awayPlayer,
    required this.round,
    this.homeLegs,
    this.awayLegs,
    this.allowsBye = false,
    this.label,
    this.isAnnulled = false,
    this.isDecider = false,
  });

  factory GroupMatch.fromJson(Map<String, dynamic> json) {
    return GroupMatch(
      homePlayer: _playerFromJson(json['homePlayer']),
      awayPlayer: _playerFromJson(json['awayPlayer']),
      round: json['round'] as int? ?? 1,
      homeLegs: json['homeLegs'] as int?,
      awayLegs: json['awayLegs'] as int?,
      allowsBye: json['allowsBye'] as bool? ?? false,
      label: json['label'] as String?,
      isAnnulled: json['isAnnulled'] as bool? ?? false,
      isDecider: json['isDecider'] as bool? ?? false,
    );
  }

  TournamentPlayer? homePlayer;
  TournamentPlayer? awayPlayer;
  final int round;
  int? homeLegs;
  int? awayLegs;
  final bool allowsBye;
  final String? label;
  bool isAnnulled;
  final bool isDecider;

  bool get hasPlayers => homePlayer != null && awayPlayer != null;
  bool get hasScore => hasPlayers && homeLegs != null && awayLegs != null;
  bool get hasResult => hasScore && !isAnnulled;
  bool get isResolved => isAnnulled || hasResult || winner != null;

  TournamentPlayer? get winner {
    if (allowsBye && homePlayer != null && awayPlayer == null) {
      return homePlayer;
    }
    if (allowsBye && awayPlayer != null && homePlayer == null) {
      return awayPlayer;
    }
    if (!hasResult) {
      return null;
    }
    if (homeLegs! == awayLegs!) {
      return null;
    }

    return homeLegs! > awayLegs! ? homePlayer : awayPlayer;
  }

  TournamentPlayer? get loser {
    final winningPlayer = winner;
    if (winningPlayer == null || !hasResult) {
      return null;
    }

    return winningPlayer == homePlayer ? awayPlayer : homePlayer;
  }

  Map<String, dynamic> toJson() {
    return {
      'homePlayer': homePlayer?.toJson(),
      'awayPlayer': awayPlayer?.toJson(),
      'round': round,
      'homeLegs': homeLegs,
      'awayLegs': awayLegs,
      'allowsBye': allowsBye,
      'label': label,
      'isAnnulled': isAnnulled,
      'isDecider': isDecider,
    };
  }
}

class PlayerStanding {
  PlayerStanding(this.player);

  final TournamentPlayer player;
  int played = 0;
  int wins = 0;
  int draws = 0;
  int losses = 0;
  int legsFor = 0;
  int legsAgainst = 0;
  int points = 0;

  int get legDifference => legsFor - legsAgainst;
}

class BestOfCandidate {
  const BestOfCandidate({
    required this.groupName,
    required this.groupNumber,
    required this.place,
    required this.standing,
  });

  final String groupName;
  final int groupNumber;
  final int place;
  final PlayerStanding standing;
}

class QualificationPlan {
  const QualificationPlan({
    required this.totalQualifiers,
    required this.fixedPerGroup,
    required this.extraCount,
    required this.extraRank,
    required this.eligibleGroupSize,
    required this.extraGroups,
    this.fixedByGroup = const [],
  });

  final int totalQualifiers;
  final int fixedPerGroup;
  final int extraCount;
  final int extraRank;
  final int? eligibleGroupSize;
  final List<int> extraGroups;
  final List<int> fixedByGroup;

  factory QualificationPlan.fromJson(Map<String, dynamic> json) {
    return QualificationPlan(
      totalQualifiers: json['totalQualifiers'] as int? ?? 0,
      fixedPerGroup: json['fixedPerGroup'] as int? ?? 0,
      extraCount: json['extraCount'] as int? ?? 0,
      extraRank: json['extraRank'] as int? ?? 0,
      eligibleGroupSize: json['eligibleGroupSize'] as int?,
      extraGroups: _intListFromJson(json['extraGroups']),
      fixedByGroup: _intListFromJson(json['fixedByGroup']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'totalQualifiers': totalQualifiers,
      'fixedPerGroup': fixedPerGroup,
      'extraCount': extraCount,
      'extraRank': extraRank,
      'eligibleGroupSize': eligibleGroupSize,
      'extraGroups': extraGroups,
      'fixedByGroup': fixedByGroup,
    };
  }

  String get summary {
    final fixedText = fixedPerGroup == 0
        ? 'keine sicheren Plaetze'
        : 'Top $fixedPerGroup je Gruppe';

    if (extraCount == 0) {
      return '$totalQualifiers Weiterkommende - $fixedText';
    }

    final groupText = extraGroups.isEmpty
        ? ''
        : ' aus ${_formatGroupSelection(extraGroups)}';

    return '$totalQualifiers Weiterkommende - $fixedText + '
        'beste $extraCount $extraRank. Plaetze$groupText';
  }

  String _formatGroupSelection(List<int> groups) {
    if (groups.length == 1) {
      return groupLabel(groups.first);
    }

    return groups.map(groupLabel).join(', ');
  }
}

