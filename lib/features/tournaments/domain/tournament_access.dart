import '../../communities/domain/community_permissions.dart';

enum ResultEntryMode { directors, selected, members }

class TournamentAccessSettings {
  const TournamentAccessSettings({
    this.creatorUserId,
    this.directorUserIds = const [],
    this.resultEntryMode = ResultEntryMode.directors,
    this.resultUserIds = const [],
  });
  final String? creatorUserId;
  final List<String> directorUserIds, resultUserIds;
  final ResultEntryMode resultEntryMode;
  factory TournamentAccessSettings.fromJson(Map<String, dynamic>? json) =>
      TournamentAccessSettings(
        creatorUserId: json?['creatorUserId'] as String?,
        directorUserIds: List<String>.unmodifiable(
          (json?['directorUserIds'] as List? ?? []).cast<String>(),
        ),
        resultEntryMode:
            ResultEntryMode.values
                .where((v) => v.name == json?['resultEntryMode'])
                .firstOrNull ??
            ResultEntryMode.directors,
        resultUserIds: List<String>.unmodifiable(
          (json?['resultUserIds'] as List? ?? []).cast<String>(),
        ),
      );
  Map<String, dynamic> toJson() => {
    'creatorUserId': creatorUserId,
    'directorUserIds': directorUserIds,
    'resultEntryMode': resultEntryMode.name,
    'resultUserIds': resultUserIds,
  };
  TournamentAccessSettings withCreator(String? user) =>
      TournamentAccessSettings(
        creatorUserId: user,
        directorUserIds: directorUserIds,
        resultEntryMode: resultEntryMode,
        resultUserIds: resultUserIds,
      );
}

class TournamentAccess {
  const TournamentAccess({
    this.canLead = false,
    this.canEnterResults = false,
    this.canConfigure = false,
  });
  static const local = TournamentAccess(
    canLead: true,
    canEnterResults: true,
    canConfigure: true,
  );
  final bool canLead, canEnterResults, canConfigure;
  static TournamentAccess resolve(
    TournamentAccessSettings settings,
    String? userId,
    CommunityPermissions rights, {
    required bool isMember,
  }) {
    if (userId == null || !isMember) return const TournamentAccess();
    final creator = settings.creatorUserId == userId;
    final lead =
        creator ||
        settings.directorUserIds.contains(userId) ||
        rights.allows(CommunityPermission.leadTournaments);
    return TournamentAccess(
      canLead: lead,
      canConfigure:
          creator || rights.allows(CommunityPermission.editTournaments),
      canEnterResults:
          lead ||
          settings.resultEntryMode == ResultEntryMode.members ||
          (settings.resultEntryMode == ResultEntryMode.selected &&
              settings.resultUserIds.contains(userId)),
    );
  }
}
