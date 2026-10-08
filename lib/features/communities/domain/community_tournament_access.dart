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
  const runtime = {'runStages', 'activeStageIndex', 'completedStageIndexes',
    'startedAt', 'finishedAt', 'plannedMinutes', 'plannedMatches', 'plannedMatchEndSeconds', 'blockedBoards', 'allowDeviceStart'};
  final oldCreator = (old['access'] as Map?)?['creatorUserId'];
  final nextCreator = (next['access'] as Map?)?['creatorUserId'];
  if (oldCreator != nextCreator) throw StateError('Turniererstellung ist unveränderlich.');
  final required = <CommunityPermission>{};
  for (final key in {...old.keys, ...next.keys}..removeAll({'updatedAt', 'syncRevision'})) {
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
