import '../../tournaments/application/order_of_play/order_of_play_controller.dart';
import '../../tournaments/domain/tournament_models.dart';

CreatedTournament assignTournamentRegistration(
  CreatedTournament source,
  Map<String, dynamic> request,
  TournamentPlayer? existing,
) {
  final key =
      request['user_id'] as String? ??
      existing?.profileId ??
      request['id'] as String;
  if (existing == null && source.players.any((p) => p.profileId == key)) {
    return CreatedTournament.fromJson(source.toJson());
  }
  if (source.players.any((p) => p.profileId == key && p != existing)) {
    throw StateError(
      'Dieser Account ist bereits einem anderen Teilnehmer zugeordnet.',
    );
  }
  if (existing?.isTeam == true) {
    throw StateError('Bitte die Anmeldung einem Einzelspieler zuordnen.');
  }
  if (existing != null &&
      existing.profileId != null &&
      request['user_id'] != null &&
      existing.profileId != request['user_id']) {
    throw StateError(
      'Der Spieler ist bereits einem anderen Profil zugeordnet.',
    );
  }
  final result = CreatedTournament.fromJson(source.toJson());
  if (existing == null) {
    if (source.activeStageIndex != 0 ||
        source.completedStageIndexes.isNotEmpty ||
        const OrderOfPlayController()
            .entries(source)
            .any((e) => e.match.hasResult || e.match.startedAt != null)) {
      throw StateError(
        'Das Turnier hat bereits begonnen. Bitte einen vorhandenen Spieler auswählen.',
      );
    }
    result.players.add(
      TournamentPlayer(
        profileId: key,
        name: request['display_name'] as String,
        isGenerated: false,
      ),
    );
    final stage = result.stages.first.toJson();
    final sizes = List<int>.from(result.stages.first.groupSizes);
    if (sizes.isNotEmpty) {
      var smallest = 0;
      for (var i = 1; i < sizes.length; i++) {
        if (sizes[i] < sizes[smallest]) smallest = i;
      }
      sizes[smallest]++;
      stage['groupSizes'] = sizes;
    }
    var bracket = 2;
    while (bracket < result.players.length) {
      bracket *= 2;
    }
    stage['knockoutParticipantCount'] = result.players.length;
    stage['knockoutBracketSize'] = bracket;
    stage['knockoutByeCount'] = bracket - result.players.length;
    stage['knockoutSlotOrder'] = <int>[];
    stage['groupSlotOrder'] = <int>[];
    result.stages[0] = TournamentStage.fromJson(stage);
    return result;
  }
  Object? remap(Object? value) {
    if (value is List) return value.map(remap).toList();
    if (value is Map<String, dynamic>) {
      if (value.containsKey('isGenerated') &&
          value['name'] == existing.name &&
          value['profileId'] == existing.profileId) {
        return {...value, 'profileId': key, 'isGenerated': false,
          if (request['user_id'] != null) 'name': request['display_name']};
      }
      return value.map((k, v) => MapEntry(k, remap(v)));
    }
    return value;
  }

  return CreatedTournament.fromJson(
    remap(source.toJson()) as Map<String, dynamic>,
  );
}
