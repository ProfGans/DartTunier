import 'dart:convert';
import 'community_permissions.dart';

Set<CommunityPermission> requiredTournamentPermissions(
  Map<String, dynamic>? old,
  Map<String, dynamic> next,
) {
  if (old == null) return {CommunityPermission.createTournaments};
  if (old['communityId'] != next['communityId'] || old['id'] != next['id']) {
    throw StateError('Turnierzuordnung ist unveränderlich.');
  }
  const runtime = {'runStages', 'activeStageIndex', 'completedStageIndexes'};
  final required = <CommunityPermission>{};
  for (final key in {...old.keys, ...next.keys}..remove('updatedAt')) {
    if (jsonEncode(old[key]) != jsonEncode(next[key])) {
      required.add(
        runtime.contains(key)
            ? CommunityPermission.leadTournaments
            : CommunityPermission.editTournaments,
      );
    }
  }
  return required;
}
