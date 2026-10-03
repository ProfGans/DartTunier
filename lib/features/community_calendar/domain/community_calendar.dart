import '../../tournaments/domain/tournament_models.dart';

/// Reusable setup only: never contains participants, results or device assignments.
class CommunityTournamentPreset {
  const CommunityTournamentPreset({
    this.boardCount = 1,
    this.playerCount = 8,
    this.stageType = 'groups',
    this.gameFormat = const TournamentGameFormat(),
    this.countsForRanking = true,
    this.rankingIds = const ['default'],
  });
  final int boardCount, playerCount;
  final String stageType;
  final TournamentGameFormat gameFormat;
  final bool countsForRanking;
  final List<String> rankingIds;
  factory CommunityTournamentPreset.fromTournament(CreatedTournament value) =>
      CommunityTournamentPreset(
        boardCount: value.boardCount,
        playerCount: value.players.length.clamp(2, 256),
        stageType: value.stages.isEmpty ? 'groups' : value.stages.first.type,
        gameFormat: value.stages.isEmpty
            ? const TournamentGameFormat()
            : value.stages.first.gameFormat,
        countsForRanking: value.countsForRanking,
        rankingIds: List.unmodifiable(value.communityRankingIds),
      );
  factory CommunityTournamentPreset.fromJson(Map<String, dynamic> json) {
    if ((json['version'] ?? 1) != 1) {
      throw const FormatException('Unbekannte Vorlagenversion');
    }
    return CommunityTournamentPreset(
      boardCount: (json['boardCount'] as int? ?? 1).clamp(1, 64),
      playerCount: (json['playerCount'] as int? ?? 8).clamp(2, 256),
      stageType: json['stageType'] as String? ?? 'groups',
      gameFormat: TournamentGameFormat.fromJson(
        Map<String, dynamic>.from(json['gameFormat'] as Map? ?? {}),
      ),
      countsForRanking: json['countsForRanking'] as bool? ?? true,
      rankingIds: List<String>.unmodifiable(
        (json['rankingIds'] as List? ?? ['default']).cast<String>(),
      ),
    );
  }
  Map<String, dynamic> toJson() => {
    'version': 1,
    'boardCount': boardCount,
    'playerCount': playerCount,
    'stageType': stageType,
    'gameFormat': gameFormat.toJson(),
    'countsForRanking': countsForRanking,
    'rankingIds': rankingIds,
  };
}

class CalendarPreset {
  const CalendarPreset({
    required this.id,
    required this.name,
    required this.settings,
  });
  final String id, name;
  final CommunityTournamentPreset settings;
  factory CalendarPreset.fromJson(Map<String, dynamic> row) => CalendarPreset(
    id: row['id'] as String,
    name: row['name'] as String,
    settings: CommunityTournamentPreset.fromJson(
      Map<String, dynamic>.from(row['settings'] as Map),
    ),
  );
}

class CommunityCalendarEvent {
  const CommunityCalendarEvent({
    required this.id,
    required this.communityId,
    required this.title,
    required this.startsAt,
    this.location = '',
    this.notes = '',
    this.isTournament = true,
    this.settings = const CommunityTournamentPreset(),
  });
  final String id, communityId, title, location, notes;
  final DateTime startsAt;
  final bool isTournament;
  final CommunityTournamentPreset settings;
  DateTime reminderAt(int minutes) =>
      startsAt.subtract(Duration(minutes: minutes));
  factory CommunityCalendarEvent.fromJson(Map<String, dynamic> row) {
    final settings = Map<String, dynamic>.from(row['settings'] as Map);
    final version = settings['calendarVersion'] ?? 1;
    if (version != 1 && version != 2) {
      throw const FormatException('Unbekannte Kalenderterminversion');
    }
    final type = settings['eventType'] ?? 'tournament';
    if (type != 'tournament' && type != 'appointment') {
      throw const FormatException('Unbekannte Terminart');
    }
    return CommunityCalendarEvent(
      id: row['id'] as String,
      communityId: row['community_id'] as String,
      title: row['title'] as String,
      startsAt: DateTime.parse(row['starts_at'] as String).toLocal(),
      location: row['location'] as String? ?? '',
      notes: row['notes'] as String? ?? '',
      isTournament: type == 'tournament',
      settings: type == 'tournament'
          ? CommunityTournamentPreset.fromJson(settings)
          : const CommunityTournamentPreset(),
    );
  }
  Map<String, dynamic> toJson() => {
    'id': id,
    'community_id': communityId,
    'title': title.trim(),
    'starts_at': startsAt.toUtc().toIso8601String(),
    'location': location.trim(),
    'notes': notes.trim(),
    // Preset schema stays v1; calendar metadata is independently versioned.
    // Missing metadata in existing rows migrates to a tournament above.
    'settings': {
      if (isTournament) ...settings.toJson() else 'version': 1,
      'calendarVersion': 2,
      'eventType': isTournament ? 'tournament' : 'appointment',
    },
  };
}
