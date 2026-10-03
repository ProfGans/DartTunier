import '../../tournaments/domain/tournament_models.dart';
import '../domain/community.dart';

class CommunityTournamentImport {
  static String id(String communityId, String sourceId) =>
      'import:${Uri.encodeComponent(communityId)}:${Uri.encodeComponent(sourceId)}';
  static String playerKey(TournamentPlayer player) =>
      player.profileId ?? 'name:${player.name}';

  static CreatedTournament copy(
    CreatedTournament source,
    String communityId, {
    Map<String, CommunityMember> assignments = const {},
    bool countsForRanking = false,
    List<String> rankingIds = const [],
  }) {
    if (source.communityId != null) {
      throw ArgumentError('Nur lokale Turniere können importiert werden.');
    }
    final assigned = assignments.values.map((m) => m.playerProfileId).toList();
    if (assigned.contains(null) || assigned.toSet().length != assigned.length) {
      throw ArgumentError(
        'Jedes Community-Mitglied darf nur einem Spieler zugeordnet werden.',
      );
    }
    if (countsForRanking && rankingIds.isEmpty) {
      throw ArgumentError('Bitte eine Rangliste wählen.');
    }
    final identities = <String>{};
    for (final player in {
      for (final p in source.players.expand((p) => p.individuals))
        playerKey(p): p,
    }.values) {
      final identity =
          assignments[playerKey(player)]?.playerProfileId ?? playerKey(player);
      if (!identities.add(identity)) {
        throw ArgumentError(
          'Die Zuordnung würde zwei Teilnehmer zusammenführen.',
        );
      }
    }
    dynamic remap(dynamic value) {
      if (value is List) return value.map(remap).toList();
      if (value is! Map) return value;
      final map = Map<String, dynamic>.from(value);
      if (map.containsKey('isGenerated') &&
          map.containsKey('name') &&
          !map.containsKey('members')) {
        final member = assignments[map['profileId'] ?? 'name:${map['name']}'];
        if (member != null) {
          map['profileId'] = member.playerProfileId;
          // Preserve tournament names: brackets and startedPlayers use them.
          map['isGenerated'] = false;
        }
      }
      return map.map((key, item) => MapEntry(key, remap(item)));
    }

    final json = remap(source.toJson()) as Map<String, dynamic>;
    json['id'] = id(communityId, source.id);
    json['communityId'] = communityId;
    json['countsForRanking'] = countsForRanking;
    json['communityRankingIds'] = rankingIds;
    return CreatedTournament.fromJson(json);
  }
}
